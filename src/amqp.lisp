(in-package :cl-rabbit)

(define-condition rabbitmq-error (error)
  ()
  (:documentation "General superclass for rabbitmq errors"))

(define-condition rabbitmq-library-error (rabbitmq-error)
  ((error-code        :type keyword
                      :initarg :error-code
                      :reader rabbitmq-library-error/error-code
                      :documentation "The response type as returned by the AMQP call")
   (error-description :type string
                      :initarg :error-description
                      :reader rabbitmq-library-error/error-description))
  (:report (lambda (condition out)
             (format out "AMQP library error: ~a" (rabbitmq-library-error/error-description condition))))
  (:documentation "Error that is raised when an AMQP call fails"))

(defun %check-client-version (name major minor patch)
  (multiple-value-bind (match strings)
      (cl-ppcre:scan-to-strings "^([0-9]+)\\.([0-9]+)\\.([0-9]+)(?:-[a-z]+)?$" name)
    (unless match
      (error "Version number reported from library has unexpected format: ~s" name))
    (let ((library-major (parse-integer (aref strings 0)))
          (library-minor (parse-integer (aref strings 1)))
          (library-patch (parse-integer (aref strings 2))))
      (or (> library-major major)
          (and (= library-major major)
               (or (> library-minor minor)
                   (and (= library-minor minor)
                        (>= library-patch patch))))))))

(defun check-client-version (major minor patch)
  (%check-client-version (version) major minor patch))

(defun raise-rabbitmq-library-error (code)
  (let* ((string-ptr (amqp-error-string2 code))
         (description (cffi:foreign-string-to-lisp string-ptr)))
    (error 'rabbitmq-library-error
           :error-code (cffi:foreign-enum-keyword 'amqp-status-enum code)
           :error-description description)))

(define-condition rabbitmq-server-error (rabbitmq-error)
  ((method     :type integer
               :initarg :method
               :reader rabbitmq-server-error/method)
   (reply-code :type integer
               :initarg :reply-code
               :initform 0
               :reader rabbitmq-server-error/reply-code)
   (message    :type string
               :initarg :message
               :initform "Unknown error"
               :reader rabbitmq-server-error/message))
  (:report (lambda (condition out)
             (format out "RPC error: ~a: ~a"
                     (slot-value condition 'reply-code)
                     (slot-value condition 'message))))
  (:documentation "Error that is raised when the server reports an error condition"))

(defun raise-rabbitmq-server-error (state channel result)
  (let* ((reply (getf result 'reply))
         (id (getf reply 'id))
         (decoded (getf reply 'decoded)))

    (cond ((eql id +amqp-channel-close-method+)
           (let ((reply-code (cffi:foreign-slot-value decoded '(:struct amqp-channel-close-t) 'reply-code))
                 (reply-text (bytes->string (cffi:foreign-slot-value decoded '(:struct amqp-channel-close-t) 'reply-text))))
             ;; Send an ack to the server to indicate that the close message was received
             (if channel
                 (confirm-channel-close state channel)
                 (warn "Got channel close message and the channel value is not set"))
             (error 'rabbitmq-server-error :method id :reply-code reply-code :message reply-text)))

          ((eql id +amqp-connection-close-method+)
           (let ((reply-code (cffi:foreign-slot-value decoded '(:struct amqp-connection-close-t) 'reply-code))
                 (reply-text (bytes->string (cffi:foreign-slot-value decoded '(:struct amqp-connection-close-t) 'reply-text))))
             (error 'rabbitmq-server-error :method id :reply-code reply-code :message reply-text)))

          (t
           (error 'rabbitmq-server-error)))))

(defclass connection ()
  ((conn     :type cffi:foreign-pointer
             :initarg :conn
             :reader connection/native-connection)
   (closed-p :type t
             :initform nil
             :accessor connection/closed-p))
  (:documentation "Class representing a connection to a RabbitMQ server."))

(defmacro with-state ((state conn) &body body)
  `(progn
     (check-type ,conn connection)
     (let ((,state (connection/native-connection ,conn)))
       ,@body)))

(defclass message ()
  ((body       :type (simple-array (unsigned-byte 8) (*))
               :initarg :body
               :reader message/body)
   (properties :type list
               :initarg :properties
               :reader message/properties)))

(defmethod print-object ((obj message) stream)
  (print-unreadable-object (obj stream :type t :identity nil)
    (if (slot-boundp obj 'body)
        (format stream "LENGTH ~a" (array-dimension (slot-value obj 'body) 0))
        (format stream "NOT-BOUND"))))

(defun make-envelope-message (value)
  (make-instance 'message
                 :body (bytes->array (getf value 'body))
                 :properties (load-properties-to-alist (getf value 'properties))))

(defclass envelope ()
  ((channel      :type integer
                 :initarg :channel
                 :reader envelope/channel)
   (consumer-tag :type string
                 :initarg :consumer-tag
                 :reader envelope/consumer-tag)
   (delivery-tag :type integer
                 :initarg :delivery-tag
                 :reader envelope/delivery-tag)
   (exchange     :type string
                 :initarg :exchange
                 :reader envelope/exchange)
   (routing-key  :type string
                 :initarg :routing-key
                 :reader envelope/routing-key)
   (message      :type message
                 :initarg :message
                 :reader envelope/message)))

(defmethod print-object ((obj envelope) stream)
  (print-unreadable-safely (channel consumer-tag delivery-tag exchange routing-key) obj stream
    (format stream "CHANNEL ~s CONSUMER-TAG ~s DELIVERY-TAG ~s EXCHANGE ~s ROUTING-KEY ~s"
            channel consumer-tag delivery-tag exchange routing-key)))

(defun fail-if-null (ptr)
  (when (cffi-sys:null-pointer-p ptr)
    (error 'rabbitmq-error))
  ptr)

(defun verify-status (status)
  (let ((type (cffi:foreign-enum-keyword 'amqp-status-enum status)))
    (unless (eq type :amqp-status-ok)
      (raise-rabbitmq-library-error status))
    type))

(defun verify-rpc-reply (state channel result)
  (let ((reply-type (cffi:foreign-enum-keyword 'amqp-response-type-enum (getf result 'reply-type))))
    (case reply-type
      (:amqp-response-normal reply-type)
      (:amqp-response-server-exception (raise-rabbitmq-server-error state channel result))
      (:amqp-response-library-exception (raise-rabbitmq-library-error (getf result 'library-error)))
      (t (error "Unexpected error: ~s" reply-type)))))

(defun verify-rpc-framing-call (state channel result)
  (when (cffi:null-pointer-p result)
    (verify-rpc-reply state channel (amqp-get-rpc-reply state))))

(defun maybe-release-buffers (state)
  (amqp-maybe-release-buffers state))

(defun confirm-channel-close (state channel)
  (cffi:with-foreign-objects ((decoded '(:struct amqp-channel-close-ok-t)))
    (setf (cffi:foreign-slot-value decoded '(:struct amqp-channel-close-ok-t) 'dummy) 0)
    (amqp-send-method state channel +amqp-channel-close-ok-method+ decoded)))

(defmacro with-connection ((conn) &body body)
  "Creates a connection using NEW-CONNECTION and evaluates BODY with
the connection bound to CONN."
  (let ((conn-sym (gensym "CONN-")))
    `(let ((,conn-sym (new-connection)))
       (unwind-protect
            (let ((,conn ,conn-sym))
              ,@body)
	 (progn
	   (ignore-errors
	    (connection-close ,conn-sym))
	   (ignore-errors
	    (destroy-connection ,conn-sym)))))))

(defmacro with-channel ((connection channel) &body body)
  "Opens CHANNEL, evaluates BODY and ensures you don't leave without
closing the channel"
  (let ((conn (gensym "con"))
        (chan (gensym "chan")))
    `(let ((,conn ,connection)
           (,chan ,channel))
       (unwind-protect
            (progn (channel-open ,conn ,chan)
                   ,@body)
	 (ignore-errors
          (channel-close ,conn ,chan))))))

;;;
;;;  API calls
;;;

(defun new-connection ()
  "Create a new connection. The returned connection must be released
using DESTROY-CONNECTION. As an alternative, WITH-CONNECTION can be
used, which ensures that the connection is properly closed."
  (let ((result (fail-if-null (amqp-new-connection))))
    (make-instance 'connection :conn result)))

(defun destroy-connection (conn)
  "Close a connection that was previously created using NEW-CONNECTION."
  (unless (connection/closed-p conn)
    (with-state (state conn)
      (verify-status (amqp-destroy-connection state)))
    (setf (connection/closed-p conn) t)))

(defun tcp-socket-new (conn)
  "Create a new TCP socket.
Call CONNECTION-CLOSE to release socket resources."
  (with-state (state conn)
    (fail-if-null (amqp-tcp-socket-new state))))

(defun ssl-socket-new (conn)
  "Create a new TLS-encrypted socket.
Call CONNECTION-CLOSE to release socket resources."
  (with-state (state conn)
    (fail-if-null (amqp-ssl-socket-new state))))

(defun ssl-socket-set-cacert (socket cacert)
  "Set the CA certificate.
SOCKET is a socket object created by SSL-SOCKET-NEW.
CACERT is the path to a certificate file in PEM format."
  (check-type cacert (or string pathname))
  (unless (probe-file cacert)
    (error "Certificate file not found: ~s" cacert))
  (cffi:with-foreign-string (s (namestring cacert))
    (verify-status (amqp-ssl-socket-set-cacert socket s))))

(defun ssl-socket-set-key (socket cert key)
  "Set the client key from a buffer.

SOCKET - An SSL/TLS socket object.
CERT - Path to the client certificate in PEM format.
KEY - Path to the client key in PEM format."
  (check-type cert (or string pathname))
  (check-type key (or string pathname))
  (unless (probe-file cert)
    (error "Certificate file not found: ~s" cert))
  (unless (probe-file key)
    (error "Key file not found: ~s" key))
  (cffi:with-foreign-strings ((cert-buffer (namestring cert))
                              (key-buffer (namestring key)))
    (verify-status (amqp-ssl-socket-set-key socket cert-buffer key-buffer))))

(defun ssl-socket-set-key-buffer (socket cert key)
  "Set the client key from a buffer.

SOCKET - An SSL/TLS socket object.
CERT - Path to the client certificate in PEM format.
KEY - An array of type (UNSIGNED-BYTE 8) containing client key in PEM format."
  (check-type cert (or string pathname))
  (check-type key (array (unsigned-byte 8)))
  (unless (probe-file cert)
    (error "Certificate file not found: ~s" cert))
  (cffi:with-foreign-string (s (namestring cert))
    (with-foreign-buffer-from-byte-array (key-array key)
      (verify-status (amqp-ssl-socket-set-key-buffer socket s key-array)))))

(defun ssl-socket-set-verify (socket verify-p)
  "Enable or disable peer verification.

If peer verification is enabled then the common name in the server
certificate must match the server name. Peer verification is enabled
by default.

SOCKET - An SSL/TLS socket object.
VERIFY-P - verify Enable or disable peer verification."
  (verify-status (amqp-ssl-socket-set-verify socket (if verify-p 1 0))))

(defun set-init-ssl-library (init)
  "Sets whether rabbitmq-c initialises the underlying SSL library.

For SSL libraries that require a one-time initialisation across
a whole program (e.g., OpenSSL) this sets whether or not rabbitmq-c
will initialise the SSL library when the first call to
amqp_open_socket() is made. You should call this function with
do_init = 0 if the underlying SSL library is initialised somewhere else
the program.

Failing to initialise or double initialisation of the SSL library will
result in undefined behaviour

By default rabbitmq-c will initialise the underlying SSL library

NOTE: calling this function after the first socket has been opened with
amqp_open_socket() will not have any effect.

INIT - If NIL rabbitmq-c will not initialise the SSL library,
       otherwise rabbitmq-c will initialise the SSL library"
  (amqp-set-initialize-ssl-library (if init 1 0)))

(defun connection-close (conn &key code)
  "Closes the entire connection.
Implicitly closes all channels and informs the broker the connection
is being closed, after receiving acknowldgement from the broker it closes
the socket.

Parameters:
CONN - the connection object
CODE - the reason code for closing the connection. Defaults to AMQP_REPLY_SUCCESS."
  (check-type code (or null integer))
  (with-state (state conn)
    (verify-rpc-reply state nil (amqp-connection-close state (or code +amqp-reply-success+)))))

(defun socket-open (socket host port)
  "Open a socket connection.
This function opens a socket connection returned from TCP-SOCKET-NEW
or SSL-SOCKET-NEW."
  (check-type host string)
  (check-type port alexandria:positive-integer)
  (verify-status (amqp-socket-open socket host port)))

(defun update-product-name-in-table (table)
  (append (list (cons "product" "cl-rabbit")
                (cons "version" "0.1"))
          (remove-if (lambda (name)
                     (or (equal name "product")
                         (equal name "version")))
                   table :key #'car)))

(defun login-sasl-plain (conn vhost user password
                         &key
                           (channel-max 0) (frame-max 131072) (heartbeat 0) properties)
  "Login to the broker using the SASL PLAIN method.

Parameters:

CONN - The connection object

VHOST - the virtual host to connect to on the broker. The default on
most brokers is \"/\"

CHANNEL-MAX - the limit for the number of channels for the connection.
0 means no limit, and is a good default (AMQP_DEFAULT_MAX_CHANNELS)
Note that the maximum number of channels the protocol supports is
65535 (2^16, with the 0-channel reserved)

FRAME-MAX - the maximum size of an AMQP frame on the wire to request
of the broker for this connection. 4096 is the minimum size, 2^31-1 is
the maximum, the default value is 131072 (128 kB).

HEARTBEAT - the number of seconds between heartbeat frame to request
of the broker. A value of 0 disables heartbeats.

PROPERTIES - a table of properties to send to the broker"
  (check-type vhost string)
  (check-type user string)
  (check-type password string)
  (with-state (state conn)
    (with-amqp-table (table (update-product-name-in-table properties))
      (cffi:with-foreign-objects ((native-table '(:struct amqp-table-t)))
        (setf (cffi:mem-ref native-table '(:struct amqp-table-t)) table)
        (let ((reply (amqp-login-sasl-plain-with-properties state vhost channel-max frame-max heartbeat native-table
                                                            (cffi:foreign-enum-value 'amqp-sasl-method-enum
                                                                                     :amqp-sasl-method-plain)
                                                            user password)))
          (verify-rpc-reply state nil reply))))))

(defun channel-open (conn channel)
  (check-type channel integer)
  (with-state (state conn)
    (unwind-protect
         (verify-rpc-framing-call state nil (amqp-channel-open state channel))
      (maybe-release-buffers state))))

(defun channel-flow (conn channel active)
  "Enable/disable flow from peer.

This method asks the peer to pause or restart the flow of content data
sent by a consumer. This is a simple flow-control mechanism that a
peer can use to avoid overflowing its queues or otherwise finding
itself receiving more messages than it can process. Note that this
method is not intended for window control. It does not affect contents
returned by Basic.Get-Ok methods.

Parameters:
CONN - the connection object
CHANNEL - the channel that should be updated
ACTIVE - a boolean indicating if flow should be enabled or disabled"
  (check-type channel integer)
  (with-state (state conn)
    (unwind-protect
         (verify-rpc-framing-call state channel (amqp-channel-flow state channel (if active 1 0)))
      (maybe-release-buffers state))))

(defun channel-close (conn channel &key code)
  "Closes a channel.
Parameters:
CONN - the connection object
CHANNEL - the channel that should be closed
CODE - the reason code, defaults to AMQP_REPLY_SUCCESS"
  (check-type channel integer)
  (check-type code (or null integer))
  (with-state (state conn)
    (unwind-protect
         (verify-rpc-reply state channel (amqp-channel-close state channel (or code +amqp-reply-success+)))
      (maybe-release-buffers state))))

(defparameter *props-mapping*
  `((:content-type content-type :string string ,+amqp-basic-content-type-flag+)
    (:content-encoding content-encoding :string string ,+amqp-basic-content-encoding-flag+)
    (:delivery-mode delivery-mode :integer (unsigned-byte 8) ,+amqp-basic-delivery-mode-flag+)
    (:priority priority :integer (unsigned-byte 8) ,+amqp-basic-priority-flag+)
    (:correlation-id correlation-id :string string ,+amqp-basic-correlation-id-flag+)
    (:reply-to reply-to :string string ,+amqp-basic-reply-to-flag+)
    (:expiration expiration :string string ,+amqp-basic-expiration-flag+)
    (:message-id message-id :string string ,+amqp-basic-message-id-flag+)
    (:timestamp timestamp :integer (unsigned-byte 8) ,+amqp-basic-timestamp-flag+)
    (:type type :string string ,+amqp-basic-type-flag+)
    (:user-id user-id :string string ,+amqp-basic-user-id-flag+)
    (:app-id app-id :string string ,+amqp-basic-app-id-flag+)
    (:cluster-id cluster-id :string string ,+amqp-basic-cluster-id-flag+)
    (:headers headers :table list ,+amqp-basic-headers-flag+)))

(defun load-properties-to-alist (props)
  (loop
     with flags = (getf props 'flags)
     for def in *props-mapping*
     when (not (zerop (logand flags (fifth def))))
     collect (let ((value (getf props (second def))))
               (cons (first def)
                     (ecase (third def)
                       (:string (bytes->string value))
                       (:integer value)
                       (:table (amqp-table->lisp value)))))))

(defun fill-in-properties-alist (properties)
  (let ((allocated-values nil)
        (flags 0))
    (unwind-when-fail
        (labels ((string-native (string)
                   (let* ((utf (babel:string-to-octets string :encoding :utf-8))
                          (ptr (array-to-foreign-char-array utf)))
                     (push ptr allocated-values)
                     (list 'len (array-dimension utf 0) 'bytes ptr))))

          (let ((res (loop
                        for (key . value) in properties
                        for def = (find key *props-mapping* :key #'first)
                        unless def
                        do (error "Unknown property in alist: ~s" key)
                        unless (typep value (fourth def))
                        do (error "Illegal type for ~s: ~s. Expected: ~s" (first def) (type-of value) (fourth def))
                        do (setf flags (logior flags (fifth def)))
                        append (list (second def) (ecase (third def)
                                                    (:string (string-native value))
                                                    (:integer value)
                                                    (:table (multiple-value-bind (table native-values)
                                                                (allocate-amqp-table value)
                                                              (dolist (v native-values)
                                                                (push v allocated-values))
                                                              table)))))))
            (values (nconc (list 'flags flags) res)
                    allocated-values)))
      ;; Unwind form (only when an error was thrown)
      (dolist (ptr allocated-values)
        (cffi:foreign-free ptr)))))

(defun basic-ack (conn channel delivery-tag &key multiple)
  "Acknowledges a message.
Does a basic.ack on a received message.

Parameters:
CONN - the connection object
CHANNEL - the channel identifier
MULTIPLE - if true, ack all messages up to this delivery tag, if
false ack only this delivery tag"
  (check-type channel integer)
  (with-state (state conn)
    (unwind-protect
         (let ((result (amqp-basic-ack state channel delivery-tag (if multiple 1 0))))
           (unless (zerop result)
             (error 'rabbitmq-error)))
      (maybe-release-buffers state))))

(defun basic-nack (conn channel delivery-tag &key multiple requeue)
  "Do a basic.nack.
Actively reject a message, this has the same effect as amqp_basic_reject()
however, amqp_basic_nack() can negatively acknowledge multiple messages with
one call much like amqp_basic_ack() can acknowledge mutliple messages with
one call.

Parameters:
CONN - the connection object
CHANNEL - the channel identifier
DELIVERY-TAG - the delivery tag of the message to reject
MULTIPLE - if true negatively acknowledge all unacknowledged messages on this channel
REQUEUE - indicate to the broker whether it should requeue the message"
  (check-type channel integer)
  (check-type delivery-tag integer)
  (with-state (state conn)
    (unwind-protect
         (verify-status (amqp-basic-nack state channel delivery-tag (if multiple 1 0) (if requeue 1 0)))
      (maybe-release-buffers state))))

(defun basic-publish (conn channel &key
                                     exchange routing-key mandatory immediate properties
                                     body (encoding :utf-8))
  "Publish a message on an exchange with a routing key.
Note that at the AMQ protocol level basic.publish is an async method:
this means error conditions that occur on the broker (such as
publishing to a non-existent exchange) will not be reflected in the
return value of this function.

Parameters:

CONN - the connection on which to send the message.

CHANNEL - the channel that should be used.

EXCHANGE - the exchange on the broker to publish to

ROUTING-KEY - the routing key to use when publishing the message

MANDATORY - indicate to the broker that the message MUST be routed to
a queue. If the broker cannot do this it should respond with a
basic.reject method

IMMEDIATE - indicate to the broker that the message MUST be delivered
to a consumer immediately. If the broker cannot do this it should
response with a basic.reject method.

BODY - can be either a vector of bytes, or a string. If it's a string,
then it will be encoded using ENCODING before sending.

PROPERTIES - indicates an alist of message properties. The
following property keywords are accepted:
:CONTENT-TYPE :CONTENT-ENCODING :DELIVERY-MODE :PRIORITY :CORRELATION-ID
:REPLY-TO :EXPIRATION :MESSAGE-ID :TIMESTAMP :TYPE :USER-ID :APP-ID :CLUSTER-ID :HEADERS"
  (check-type channel integer)
  (check-type exchange (or null string))
  (check-type routing-key (or null string))
  (check-type body (or null vector string))
  (with-state (state conn)
    (unwind-protect
         (with-bytes-strings ((exchange-bytes exchange)
                              (routing-key-bytes routing-key))
           (labels ((send-with-properties (data props)
                      (verify-status (amqp-basic-publish state channel exchange-bytes routing-key-bytes
                                                         (if mandatory 1 0) (if immediate 1 0)
                                                         props data)))

                    (send-with-data (data)
                      (if properties
                          (cffi:with-foreign-objects ((p '(:struct amqp-basic-properties-t)))
                            (multiple-value-bind (props-list allocated)
                                (fill-in-properties-alist properties)
                              (unwind-protect
                                   (progn
                                     (setf (cffi:mem-ref p '(:struct amqp-basic-properties-t)) props-list)
                                     (send-with-properties data p))
                                (dolist (ptr allocated)
                                  (cffi:foreign-free ptr)))))
                          ;; ELSE: No properties argument
                          (send-with-properties data (cffi:null-pointer)))))

             (if body
                 (with-bytes-struct (body-val (etypecase body
                                                (string (babel:string-to-octets body :encoding encoding))
                                                (vector body)))
                   (send-with-data body-val))
                 ;; ELSE: body is nil, send a blank struct
                 (send-with-data (list 'len 0 'bytes (cffi-sys:null-pointer))))))
      (maybe-release-buffers state))))

(defun exchange-declare (conn channel exchange type &key passive durable auto-delete internal arguments)
  (check-type channel integer)
  (check-type exchange string)
  (check-type type string)
  (let ((version-0-6 (check-client-version 0 6 0)))
    (unless version-0-6
      (when auto-delete
        (error ":AUTO-DELETE is not supported in rabbitmq-c versions before 0.6.0"))
      (when internal
        (error ":INTERNAL is not supported in rabbitmq-c versions before 0.6.0")))
    (with-state (state conn)
      (unwind-protect
           (with-bytes-strings ((exchange-bytes exchange)
                                (type-bytes type))
             (with-amqp-table (table arguments)
               (if version-0-6
                   (verify-rpc-framing-call state channel
                                            (amqp-exchange-declare-0-6 state channel exchange-bytes type-bytes
                                                                       (if passive 1 0) (if durable 1 0)
                                                                       (if auto-delete 1 0) (if internal 1 0)
                                                                       table))
                   (verify-rpc-framing-call state channel
                                            (amqp-exchange-declare-0-5 state channel exchange-bytes type-bytes
                                                                       (if passive 1 0) (if durable 1 0)
                                                                       table)))))
        (maybe-release-buffers state)))))

(defun exchange-delete (conn channel exchange &key if-unused)
  (check-type channel integer)
  (check-type exchange string)
  (with-state (state conn)
    (unwind-protect
         (with-bytes-strings ((exchange-bytes exchange))
           (verify-rpc-framing-call state channel (amqp-exchange-delete state channel exchange-bytes (if if-unused 1 0))))
      (maybe-release-buffers state))))

(defun exchange-bind (conn channel &key destination source routing-key arguments)
  (check-type channel integer)
  (check-type destination (or null string))
  (check-type source (or null string))
  (check-type routing-key (or null string))
  (with-state (state conn)
    (unwind-protect
         (with-bytes-strings ((destination-bytes destination)
                              (source-bytes source)
                              (routing-key-bytes routing-key))
           (with-amqp-table (table arguments)
             (verify-rpc-framing-call state channel
                                      (amqp-exchange-bind state channel destination-bytes source-bytes
                                                          routing-key-bytes table))))
      (maybe-release-buffers state))))

(defun exchange-unbind (conn channel &key destination source routing-key)
  (check-type channel integer)
  (check-type destination (or null string))
  (check-type source (or null string))
  (check-type routing-key (or null string))
  (with-state (state conn)
    (unwind-protect
         (with-bytes-strings ((destination-bytes destination)
                              (source-bytes source)
                              (routing-key-bytes routing-key))
           (verify-rpc-framing-call state channel
                                    (amqp-exchange-unbind state channel destination-bytes source-bytes
                                                          routing-key-bytes amqp-empty-table)))
      (maybe-release-buffers state))))

(defun queue-declare (conn channel &key queue passive durable exclusive auto-delete arguments)
  "Declare queue, create if needed.

This method creates or checks a queue. When creating a new queue the
client can specify various properties that control the durability of
the queue and its contents, and the level of sharing for the queue.

This function returns three values: The name of the queue, the number
of messages waiting on the queue, the number of consumers for this
queue."
  (check-type channel integer)
  (check-type queue (or null string))
  (with-state (state conn)
    (unwind-protect
         (with-bytes-string (queue-bytes queue)
           (with-amqp-table (table arguments)
             (let ((result (amqp-queue-declare state channel queue-bytes (if passive 1 0) (if durable 1 0)
                                               (if exclusive 1 0) (if auto-delete 1 0) table)))
               (verify-rpc-framing-call state channel result)
               (values (bytes->string (cffi:foreign-slot-value result
                                                               '(:struct amqp-queue-declare-ok-t)
                                                               'queue))
                       (cffi:foreign-slot-value result '(:struct amqp-queue-declare-ok-t) 'message-count)
                       (cffi:foreign-slot-value result '(:struct amqp-queue-declare-ok-t) 'consumer-count)))))
      (maybe-release-buffers state))))

(defun queue-bind (conn channel &key queue exchange routing-key arguments)
  "Bind queue to an exchange.

This method binds a queue to an exchange. Until a queue is bound it
will not receive any messages. In a classic messaging model,
store-and-forward queues are bound to a direct exchange and
subscription queues are bound to a topic exchange."
  (check-type channel integer)
  (check-type queue (or null string))
  (check-type exchange (or null string))
  (check-type routing-key (or null string))
  (with-state (state conn)
    (unwind-protect
         (with-bytes-strings ((queue-bytes queue)
                              (exchange-bytes exchange)
                              (routing-key-bytes routing-key))
           (with-amqp-table (table arguments)
             (verify-rpc-framing-call state channel
                                      (amqp-queue-bind state channel queue-bytes exchange-bytes
                                                       routing-key-bytes table))))
      (maybe-release-buffers state))))

(defun queue-unbind (conn channel &key queue exchange routing-key arguments)
  (check-type channel integer)
  (check-type queue (or null string))
  (check-type exchange (or null string))
  (check-type routing-key (or null string))
  (with-state (state conn)
    (unwind-protect
         (with-bytes-strings ((queue-bytes queue)
                              (exchange-bytes exchange)
                              (routing-key-bytes routing-key))
           (with-amqp-table (table arguments)
             (verify-rpc-framing-call state channel
                                      (amqp-queue-unbind state channel queue-bytes exchange-bytes
                                                         routing-key-bytes table))
             nil))
      (maybe-release-buffers state))))

(defun queue-purge (conn channel queue)
  (check-type channel integer)
  (check-type queue string)
  (with-state (state conn)
    (unwind-protect
         (with-bytes-strings ((queue-bytes queue))
           (verify-rpc-framing-call conn channel (amqp-queue-purge state channel queue-bytes)))
      (maybe-release-buffers state))))

(defun queue-delete (conn channel queue &key if-unused if-empty)
  (check-type channel integer)
  (check-type queue string)
  (with-state (state conn)
    (unwind-protect
         (with-bytes-strings ((queue-bytes queue))
           (verify-rpc-framing-call conn channel (amqp-queue-delete state channel queue-bytes (if if-unused 1 0) (if if-empty 1 0))))
      (maybe-release-buffers state))))

(defun basic-consume (conn channel queue &key consumer-tag no-local no-ack exclusive arguments)
  (check-type channel integer)
  (check-type queue string)
  (check-type consumer-tag (or null string))
  (with-state (state conn)
    (unwind-protect
         (with-bytes-strings ((queue-bytes queue)
                              (consumer-tag-bytes consumer-tag))
           (with-amqp-table (table arguments)
             (let ((result (amqp-basic-consume state channel queue-bytes consumer-tag-bytes
                                               (if no-local 1 0) (if no-ack 1 0) (if exclusive 1 0) table)))
               (verify-rpc-framing-call state channel result)
               (bytes->string (cffi:foreign-slot-value result '(:struct amqp-basic-consume-ok-t) 'consumer-tag)))))
      (maybe-release-buffers state))))

(defun basic-qos (conn channel &key (global t) (prefetch-size 0) (prefetch-count 1))
  (check-type channel integer)
  (check-type prefetch-size integer)
  (check-type prefetch-count integer)
  (with-state (state conn)
    (unwind-protect
         (verify-rpc-framing-call state channel
				  (amqp-basic-qos state channel prefetch-size prefetch-count (if global 1 0)))
      (maybe-release-buffers state))))

(defun consume-message (conn &key timeout)
  "Wait for and consume a message.
Waits for a basic.deliver method on any channel, upon receipt of
basic.deliver it reads that message, and returns. If any other method
is received before basic.deliver, this function will raise a
RABBITMQ-LIBRARY-ERROR with its error code set
to :AMQP-UNEXPECTED-FRAME. The caller should then call
amqp_simple_wait_frame() to read this frame and take appropriate
action.

This function should be used after starting a consumer with the
BASIC-CONSUME function.

This function returns an instance of ENVELOPE that contains the
consumed message.

Parameters:

CONN - the connection object

TIMEOUT - the number of microseconds to wait for a message delivery.
Passing in NIL will result in blocking behaviour."
  (check-type timeout (or null integer))
  (with-state (state conn)
    (unwind-protect
         (with-foreign-timeval (native-timeout timeout)
           (cffi:with-foreign-objects ((envelope '(:struct amqp-envelope-t)))
             (verify-rpc-reply state nil (amqp-consume-message state envelope native-timeout 0))
             (unwind-protect
                  (flet ((getval (slot-name)
                           (cffi:foreign-slot-value envelope '(:struct amqp-envelope-t) slot-name)))
                    (make-instance 'envelope
                                   :channel (getval 'channel)
                                   :consumer-tag (bytes->string (getval 'consumer-tag))
                                   :delivery-tag (getval 'delivery-tag)
                                   :exchange (bytes->string (getval 'exchange))
                                   :routing-key (bytes->string (getval 'routing-key))
                                   :message (make-envelope-message (getval 'message))))
               (amqp-destroy-envelope envelope))))
      (maybe-release-buffers state))))

(defun basic-cancel (conn channel consumer-tag)
  (check-type channel integer)
  (check-type consumer-tag string)
  (with-state (state conn)
    (unwind-protect
         (with-bytes-strings ((consumer-tag-bytes consumer-tag))
           (verify-rpc-framing-call state channel (amqp-basic-cancel state channel consumer-tag-bytes)))
      (maybe-release-buffers state))))

;; Currently disabled, since it leaves the input buffer in an unpredictable state
#+nil
(defun basic-get (conn channel queue &key no-ack)
  "Do a basic.get
Synchonously polls the broker for a message in a queue, and
retrieves the message if a message is in the queue.

Parameters:
CONN - the connection object
CHANNEL - the channel identifier to use
QUEUE - the queue name to receive from
NO-ACK if true the message is automatically ack'ed
if false amqp_basic_ack should be called once the message
retrieved has been processed"
  (check-type channel int)
  (check-type queue string)
  (with-state (state conn)
    (unwind-protect
         (with-bytes-string (queue-bytes queue)
           (verify-rpc-reply state (amqp-basic-get state channel queue-bytes (if no-ack 1 0))))
      (maybe-release-buffers state))))

(defun data-in-buffer (conn)
  (with-state (state conn)
    (unwind-protect
         (not (zerop (amqp-data-in-buffer state)))
      (maybe-release-buffers state))))

(defun frames-enqueued (conn)
  (with-state (state conn)
    (unwind-protect
         (not (zerop (amqp-frames-enqueued state)))
      (maybe-release-buffers state))))

(defun get-sockfd (conn)
  (with-state (state conn)
    (amqp-get-sockfd state)))

(defun version ()
  (amqp-version))

(defun tx-select (conn channel)
  (check-type channel integer)
  (with-state (state conn)
    (unwind-protect
         (verify-rpc-framing-call state channel (amqp-tx-select state channel))
      (maybe-release-buffers state))))

(defun tx-commit (conn channel)
  (check-type channel integer)
  (with-state (state conn)
    (unwind-protect
         (verify-rpc-framing-call state channel (amqp-tx-commit state channel))
      (maybe-release-buffers state))))

(defun tx-rollback (conn channel)
  (check-type channel integer)
  (with-state (state conn)
    (unwind-protect
         (verify-rpc-framing-call state channel (amqp-tx-rollback state channel))
      (maybe-release-buffers state))))


(defclass method-frame ()
  ((channel :type integer
            :initarg :channel
            :reader method-frame/channel
            :documentation "Frame channel.")
   (id :type integer
       :reader method-frame/id
       :documentation "Method id."))
  (:documentation "Parent class for all method frames."))

(defclass method-frame-basic-acknowledgment (method-frame)
  ((channel :reader method-frame-basic-acknowledgment/channel)
   (id :initform #.+amqp-basic-ack-method+
       :reader method-frame-basic-acknowledgment/id
       :allocation :class
       :documentation "Basic acknowledgment method ID.")
   (delivery-tag :type integer
                 :initarg :delivery-tag
                 :reader method-frame-basic-acknowledgment/delivery-tag
                 :documentation "Sequence number of the confirmed message.")
   (multiplep :type t
              :initarg :multiplep
              :reader method-frame-basic-acknowledgment/multiplep
              :documentation "t when acknowledge messages up to and including the one with the
sequence in delivery-tag."))
  (:documentation "Basic acknowledgment method frame."))

(defun make-method-frame-basic-acknowledgment (channel delivery-tag multiplep)
  "Returns fresh object of METHOD-FRAME-BASIC-ACKNOWLEDGMENT.

Arguments:

CHANNEL => INTEGER, Rabbitmq channel.
DELIVERY-TAG => INTEGER, sequence number of confirmed message.
MULTIPLEP => BOOLEAN, t when acknowledge messages up to and including the one with the sequence in delivery-tag."
  (check-type channel integer)
  (check-type delivery-tag integer)
  (make-instance 'method-frame-basic-acknowledgment
                 :channel channel
                 :delivery-tag delivery-tag
                 :multiplep multiplep))

(defmethod print-object ((obj method-frame-basic-acknowledgment) stream)
  (print-unreadable-safely (channel id delivery-tag multiplep) obj stream
    (format stream "CHANNEL ~s ID ~s DELIVERY-TAG ~s MULTIPLEP ~s"
            channel id delivery-tag multiplep)))

(defclass method-frame-basic-negative-acknowledgment (method-frame)
  ((channel :reader method-frame-basic-negative-acknowledgment/channel)
   (id :initform #.+amqp-basic-nack-method+
       :reader method-frame-basic-negative-acknowledgment/id
       :allocation :class
       :documentation "Basic negative acknowledgment method ID.")
   (delivery-tag :type integer
                 :initarg :delivery-tag
                 :reader method-frame-basic-negative-acknowledgment/delivery-tag
                 :documentation "Sequence number of the negatively confirmed message.")
   (multiplep :type t
              :initarg :multiplep
              :reader method-frame-basic-negative-acknowledgment/multiplep
              :documentation "t when acknowledge messages up to and including the one with the
sequence in delivery-tag.")
   (requeuep :type t
             :initarg :requeuep
             :reader method-frame-basic-negative-acknowledgment/requeuep
             :documentation "t when instructing the broker to requeue message. this slot should be
ignored when publisher receives negative acknowledgment from broker."))
  (:documentation "Basic negative acknowledgment (nack) method frame."))

(defun make-method-frame-basic-negative-acknowledgment (channel delivery-tag multiplep requeuep)
  "Returns fresh object of METHOD-FRAME-BASIC-NEGATIVE-ACKNOWLEDGMENT

Arguments:

CHANNEL => INTEGER, Rabbitmq channel.
DELIVERY-TAG => INTEGER, sequence number of confirmed message.
MULTIPLEP => BOOLEAN, t when acknowledge messages up to and including the one with the sequence in delivery-tag.
REQUEUEP => BOOLEAN, t when instructing the broker to requeue message. this slot should be
ignored when publisher receives negative acknowledgment from broker."
  (check-type channel integer)
  (check-type delivery-tag integer)
  (make-instance 'method-frame-basic-negative-acknowledgment
                 :channel channel
                 :delivery-tag delivery-tag
                 :multiplep multiplep
                 :requeuep requeuep))

(defmethod print-object ((obj method-frame-basic-negative-acknowledgment) stream)
  (print-unreadable-safely (channel id delivery-tag multiplep requeuep) obj stream
    (format stream "CHANNEL ~s ID ~s DELIVERY-TAG ~s MULTIPLEP ~s REQUEUEP ~s"
            channel id delivery-tag multiplep requeuep)))

(defclass method-frame-basic-return (method-frame)
  ((channel :reader method-frame-basic-return/channel)
   (id :initform #.+amqp-basic-return-method+
       :reader method-frame-basic-return/id
       :allocation :class
       :documentation "Basic return method ID.")
   (reply-code :type integer
               :initarg :reply-code
               :reader method-frame-basic-return/reply-code
               :documentation "The AMQ reply code.")
   (reply-text :type string
               :initarg :reply-text
               :reader method-frame-basic-return/reply-text
               :documentation "The localized reply text. this text can be logged as an aid to resolving issues.")
   (exchange :type string
             :initarg :exchange
             :reader method-frame-basic-return/exchange
             :documentation "Exchange name.")
   (routing-key :type string
                :initarg :routing-key
                :reader method-frame-basic-return/routing-key
                :documentation "Message routing key."))
  (:documentation "Basic return method frame."))

(defun make-method-frame-basic-return (channel reply-code reply-text exchange routing-key)
  "Returns fresh object of METHOD-FRAME-BASIC-RETURN.

Arguments:

CHANNEL => INTEGER, Rabbitmq channel.
REPLY-CODE => INTEGER, AMQ reply code.
REPLY-TEXT => STRING, localized reply text. this text can be logged as an aid to resolving issues.
EXCHANGE => STRING, Rabbitmq exchange name.
ROUTING-KEY => STRING, Message routing key."
  (check-type channel integer)
  (check-type reply-code integer)
  (check-type reply-text string)
  (check-type exchange string)
  (check-type routing-key string)
  (make-instance 'method-frame-basic-return
                 :channel channel
                 :reply-code reply-code
                 :reply-text reply-text
                 :exchange exchange
                 :routing-key routing-key))

(defmethod print-object ((obj method-frame-basic-return) stream)
  (print-unreadable-safely (channel id reply-code reply-text exchange routing-key) obj stream
    (format stream "CHANNEL ~s ID ~s REPLY-CODE ~s REPLY-TEXT ~s EXCHANGE ~s ROUTING-KEY ~s"
            channel id reply-code reply-text exchange routing-key)))

(defclass method-frame-basic-deliver (method-frame)
  ((channel :reader method-frame-basic-deliver/channel)
   (id :initform #.+amqp-basic-deliver-method+
       :reader method-frame-basic-deliver/id
       :allocation :class
       :documentation "Basic deliver method ID.")
   (consumer-tag :type string
                 :initarg :consumer-tag
                 :reader method-frame-basic-deliver/consumer-tag
                 :documentation "Identifier for the consumer, valid within the current channel.
The server-assigned and channel-specific delivery tag")
   (delivery-tag :type integer
                 :initarg :delivery-tag
                 :reader method-frame-basic-deliver/delivery-tag
                 :documentation "Sequence number of confirmed message.")
   (redeliveredp :type t
                 :initarg :redeliveredp
                 :reader method-frame-basic-deliver/redeliveredp
                 :documentation "t when message is redelivered, after it was not successfully
acknowledged by a consumer.")
   (exchange :type string
             :initarg :exchange
             :reader method-frame-basic-deliver/exchange
             :documentation "Exchange name.")
   (routing-key :type string
                :initarg :routing-key
                :reader method-frame-basic-deliver/routing-key
                :documentation "Message routing key."))
  (:documentation "Basic deliver method frame."))

(defun make-method-frame-basic-deliver (channel
                                        consumer-tag
                                        delivery-tag
                                        redeliveredp
                                        exchange
                                        routing-key)
  "Returns fresh object of METHOD-FRAME-BASIC-DELIVER.

Arguments:

CHANNEL => INTEGER, Rabbitmq channel.
CONSUMER-TAG => STRING, identifier for the consumer, valid within the current channel.
DELIVERY-TAG => INTEGER, sequence number of confirmed message.
REDELIVEREDP => BOOLEAN, t when message is redelivered after it was not successfully acknowledged
by a consumer.
EXCHANGE => STRING, Exchange name.
ROUTING-KEY => STRING, Message routing key."
  (make-instance 'method-frame-basic-deliver
                 :channel channel
                 :consumer-tag consumer-tag
                 :delivery-tag delivery-tag
                 :redeliveredp redeliveredp
                 :exchange exchange
                 :routing-key routing-key))

(defmethod print-object ((obj method-frame-basic-deliver) stream)
  (print-unreadable-safely (channel id consumer-tag delivery-tag redeliveredp exchange routing-key)
      obj stream
    (format stream "CHANNEL ~s ID ~s CONSUMER-TAG ~s DELIVERY-TAG ~s REDELIVEREDP ~s ~
EXCHANGE ~s ROUTING-KEY ~s"
            channel id consumer-tag delivery-tag redeliveredp exchange routing-key)))

(defclass content-header-frame ()
  ((channel :type integer
            :initarg :channel
            :reader content-header-frame/channel
            :documentation "channel.")
   (class-id :type integer
             :initarg :class-id
             :reader content-header-frame/class-id
             :documentation "AMQP class id.")
   (body-size :type integer
              :initarg :body-size
              :reader content-header-frame/body-size
              :documentation "Body payload size in bytes.")
   (properties :type list
               :initarg :properties
               :reader content-header-frame/properties
               :documentation "Payload properties."))
  (:documentation "Content header frame."))

(defun make-content-header-frame (channel class-id body-size properties)
  "Returns fresh object of CONTENT-HEADER-FRAME

Arguments:

CHANNEL => INTEGER, Rabbitmq channel.
CLASS-ID => INTEGER, AMQP class id.
BODY-SIZE => INTEGER, Body payload size in bytes.
PROPERTIES => ALIST, Payload properties."
  (make-instance 'content-header-frame
                 :channel channel
                 :class-id class-id
                 :body-size body-size
                 :properties (load-properties-to-alist properties)))

(defmethod print-object ((obj content-header-frame) stream)
  (print-unreadable-safely (channel class-id body-size properties) obj stream
      (format stream "CHANNEL ~s CLASS-ID ~s BODY-SIZE ~s PROPERTIES ~s"
              channel class-id body-size properties)))

(defclass content-body-frame ()
  ((channel :type integer
           :initarg :channel
           :reader content-body-frame/channel
           :documentation "Rabbitmq channel.")
   (body :type (simple-array (unsigned-byte 8) (*))
         :initarg :body
         :reader content-body-frame/body
         :documentation "Body payload raw content."))
  (:documentation "Content body frame"))

(defun make-content-body-frame (channel body)
  "Returns fresh object of CONTENT-BODY-FRAME.

Arguments:

CHANNEL => INTEGER, Rabbitmq channel.
BODY => ARRAY of BYTES, contents."
  (make-instance 'content-body-frame
                 :channel channel
                 :body (bytes->array body)))
(defmethod print-object ((obj content-body-frame) stream)
  (print-unreadable-safely (channel) obj stream (format stream "CHANNEL ~s" channel)))

(defmethod foreign-method->class ((method-id (eql #.+amqp-basic-ack-method+)) method-struct channel)
  "Returns fresh object of METHOD-FRAME-BASIC-ACKNOWLEDGMENT filled with data from foreign METHOD-STRUCT.

Arguments:

METHOD-ID => CONSTANT, AMQP basic acknowledgment method id.
METHOD-STRUCT => CFFI FOREIGN POINTER, decoded basic acknowledgment method frame.
CHANNEL => INTEGER, Rabbitmq channel."
  (cffi:with-foreign-slots ((delivery-tag multiplep) method-struct (:struct amqp-basic-ack-t))
    (make-method-frame-basic-acknowledgment channel delivery-tag (> multiplep 0))))

(defmethod foreign-method->class ((method-id (eql #.+amqp-basic-nack-method+)) method-struct channel)
    "Returns fresh object of METHOD-FRAME-BASIC-NEGATIVE-ACKNOWLEDGMENT filled with data from foreign METHOD-STRUCT.

Arguments:

METHOD-ID => CONSTANT, AMQP basic acknowledgment method id.
METHOD-STRUCT => CFFI FOREIGN POINTER, decoded negative basic acknowledgment method frame.
CHANNEL => INTEGER, Rabbitmq channel."
  (cffi:with-foreign-slots ((delivery-tag multiplep requeuep)
                            method-struct
                            (:struct amqp-basic-nack-t))
    (make-method-frame-basic-negative-acknowledgment channel
                                                      delivery-tag
                                                      (> multiplep 0)
                                                      (> requeuep 0))))

(defmethod foreign-method->class ((method-id (eql #.+amqp-basic-return-method+))
                                  method-struct
                                  channel)
    "Returns fresh object of METHOD-FRAME-BASIC-RETURN filled with data from foreign METHOD-STRUCT.

Arguments:

METHOD-ID => CONSTANT, AMQP basic return method id.
METHOD-STRUCT => CFFI FOREIGN POINTER, decoded basic return method frame.
CHANNEL => INTEGER, Rabbitmq channel."
  (cffi:with-foreign-slots ((reply-code reply-text exchange routing-key)
                            method-struct
                            (:struct amqp-basic-return-t))
    (make-method-frame-basic-return channel
                                    reply-code
                                    (bytes->string reply-text)
                                    (bytes->string exchange)
                                    (bytes->string routing-key))))

(defmethod foreign-method->class ((method-id (eql #.+amqp-basic-deliver-method+))
                                  method-struct
                                  channel)
      "Returns fresh object of METHOD-FRAME-BASIC-DELIVER filled with data from foreign METHOD-STRUCT.

Arguments:

METHOD-ID => CONSTANT, AMQP basic deliver method id.
METHOD-STRUCT => CFFI FOREIGN POINTER, decoded basic deliver method frame.
CHANNEL => INTEGER, Rabbitmq channel."
  (cffi:with-foreign-slots ((consumer-tag delivery-tag redeliveredp exchange routing-key)
                            method-struct
                            (:struct amqp-basic-deliver-t))
    (make-method-frame-basic-deliver channel
                                     (bytes->string consumer-tag)
                                     delivery-tag
                                     (> redeliveredp 0)
                                     (bytes->string exchange)
                                     (bytes->string routing-key))))

(define-condition method-frame-error (rabbitmq-error)
  ((channel :type integer
            :initarg :channel
            :reader method-frame-error/channel)
   (method-id :type integer
              :initarg :method-id
              :reader method-frame-error/method-id))
  (:report (lambda (condition out)
             (format out "Method Frame Error: CHANNEL ~s METHOD-ID ~s"
                     (slot-value condition 'channel)
                     (slot-value condition 'method-id))))
  (:documentation "Error signaled when an unhandled method type recieved in a method frame."))

(defun raise-method-frame-error (channel method-id)
  "Signals an error of method"
  (error 'method-frame-error :channel channel :method-id method-id))

(defmethod foreign-method->class (method-id method-struct channel)
  "Returns t when METHOD-ID equals CONFIRM-SELECT-OK-METHOD otherwise signals and error.

Arguments:

METHOD-ID => INTEGER, AMQP basic return method id.
METHOD-STRUCT => CFFI FOREIGN POINTER, decoded method frame.
CHANNEL => INTEGER, Rabbitmq channel."
  (declare (ignore method-struct))
  (when (null (find-if #'(lambda (value)
                           (eql method-id value))
                       '(+amqp-confirm-select-ok-method+)))
    (raise-method-frame-error channel method-id))
  t)

(defun confirm-select (conn channel)
  "Set CHANNEL to publisher confirm mode. a channel in transaction mode cannot be set to confirm mode.
returns t if successful. signals RABBITMQ-SERVER-ERROR if channel is in transaction mode."
  (check-type channel integer)
  (with-state (state conn)
    (unwind-protect
         (verify-rpc-framing-call state channel (amqp-confirm-select state channel))
      (maybe-release-buffers state))))

(defun simple-wait-frame (conn)
  "Returns frame object for supported frames (see notes section), t for confirmation (ok) frames or
signals error for unsupported (not implemented frames), this function waits for frame on ANY
CHANNEL on CONN.

Arguments:
CONN => Rabbitmq connection.

NOTES:
Currently implemented frames are basic acknowledgment, basic negative acknowledgment, return,
deliver and select ok method frames, content header and content body frames."
  (with-state (state conn)
    (unwind-protect
         (labels ((extract-method-frame (frame channel)
                    (let* ((method (cffi:foreign-slot-value frame
                                                            '(:struct amqp-frame-t)
                                                            'payload-method))
                           (decoded (getf method 'decoded)))
                      (foreign-method->class (getf method 'id) decoded channel)))
                  (extract-content-header (frame channel)
                    (cffi:with-foreign-slots ((payload-properties-class-id
                                               payload-properties-body-size
                                               payload-properties-decoded)
                                              frame
                                              (:struct amqp-frame-t))
                      (make-content-header-frame channel
                                                 payload-properties-class-id
                                                 payload-properties-body-size
                                                 (cffi:mem-ref payload-properties-decoded
                                                               '(:struct amqp-basic-properties-t)))))
                  (extract-content-body (frame channel)
                    (cffi:with-foreign-slots ((payload-body-fragment) frame (:struct amqp-frame-t))
                      (make-content-body-frame channel payload-body-fragment))))
           (cffi:with-foreign-objects ((frame '(:struct amqp-frame-t)))
             (verify-status (amqp-simple-wait-frame state frame))
             (cffi:with-foreign-slots ((frame-type channel) frame (:struct amqp-frame-t))
               (ccase frame-type
                 (#.+amqp-frame-method+ (extract-method-frame frame channel))
                 (#.+amqp-frame-header+ (extract-content-header frame channel))
                 (#.+amqp-frame-body+ (extract-content-body frame channel))))))
      (maybe-release-buffers state))))
