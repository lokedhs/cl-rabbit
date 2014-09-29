(in-package :cl-rabbit)

(declaim (optimize (speed 0) (safety 3) (debug 3)))

(defun fail-if-null (ptr)
  (when (cffi-sys:null-pointer-p ptr)
    (error "Failed"))
  ptr)

(defun verify-status (status)
  (unless (= status (cffi:foreign-enum-value 'amqp-status-enum :amqp-status-ok))
    (error "Failed: ~a" status))
  status)

(defun verify-rpc-reply (reply)
  (let* ((status (getf reply 'reply-type)))
    (unless (= status (cffi:foreign-enum-value 'amqp-response-type-enum :amqp-response-normal))
      (error "Failed: ~a" status))))

(defun new-connection ()
  (fail-if-null (amqp-new-connection)))

(defun destroy-connection (state)
  (verify-status (amqp-destroy-connection state)))

(defun tcp-socket-new (connection)
  (fail-if-null (amqp-tcp-socket-new connection)))

(defun socket-open (socket host port)
  (check-type host string)
  (check-type port alexandria:positive-integer)
  (verify-status (amqp-socket-open socket host port)))

(defun login-sasl-plain (state vhost user password &key (channel-max 0) (frame-max 131072) (heartbeat 0))
  (let ((reply (amqp-login-sasl-plain state vhost
                                      channel-max frame-max
                                      heartbeat :amqp-sasl-method-plain user password)))
    (unless (= (getf reply 'reply-type) (cffi:foreign-enum-value 'amqp-response-type-enum :amqp-response-normal))
      (error "Illegal response from login"))))

(defun channel-open (state channel)
  (fail-if-null (amqp-channel-open state channel)))

(defun basic-publish (state channel exchange routing-key body
                      &key mandatory immediate)
  (check-type channel integer)
  (check-type exchange string)
  (check-type routing-key string)
  (check-type body array)
  (with-bytes-strings ((exchange-bytes exchange)
                       (routing-key-bytes routing-key))
    (with-bytes-struct (body-val body)
      (verify-status (amqp-basic-publish state channel exchange-bytes routing-key-bytes
                                         (if mandatory 1 0) (if immediate 1 0)
                                         (cffi-sys:null-pointer) body-val)))))

(defun queue-declare (state channel &key queue passive durable exclusive auto-delete)
  (check-type channel integer)
  (check-type queue (or null string))
  (with-bytes-string (queue-bytes queue)
    (let ((result (amqp-queue-declare state channel queue-bytes (if passive 1 0) (if durable 1 0)
                                      (if exclusive 1 0) (if auto-delete 1 0) amqp-empty-table)))
      (verify-rpc-reply (amqp-get-rpc-reply state))
      (values (bytes->string (cffi:foreign-slot-value result
                                                      '(:struct amqp-queue-declare-ok-t)
                                                      'queue))
              (cffi:foreign-slot-value result '(:struct amqp-queue-declare-ok-t) 'message-count)
              (cffi:foreign-slot-value result '(:struct amqp-queue-declare-ok-t) 'consumer-count)))))

(defun queue-bind (state channel queue exchange routing-key)
  (check-type channel integer)
  (check-type queue string)
  (check-type exchange string)
  (check-type routing-key string)
  (with-bytes-strings ((queue-bytes queue)
                       (exchange-bytes exchange)
                       (routing-key-bytes routing-key))
    (amqp-queue-bind state channel queue-bytes exchange-bytes routing-key-bytes amqp-empty-table)
    (verify-rpc-reply (amqp-get-rpc-reply state))
    nil))

(defun basic-consume (state channel queue &key consumer-tag no-local no-ack exclusive)
  (check-type channel integer)
  (check-type queue string)
  (check-type consumer-tag (or null string))
  (with-bytes-strings ((queue-bytes queue)
                       (consumer-tag-bytes consumer-tag))
    (let ((result (amqp-basic-consume state channel queue-bytes consumer-tag-bytes
                                      (if no-local 1 0) (if no-ack 1 0) (if exclusive 1 0) amqp-empty-table)))
      (verify-rpc-reply (amqp-get-rpc-reply state))
      (bytes->string (cffi:foreign-slot-value result '(:struct amqp-basic-consume-ok-t) 'consumer-tag)))))

(defun consume-message (state &key timeout)
  (check-type timeout (or null integer))
  (with-foreign-timeval (native-timeout timeout)
    (cffi:with-foreign-objects ((envelope '(:struct amqp-envelope-t)))
      (let ((result (amqp-consume-message state envelope native-timeout 0)))
        (verify-rpc-reply result)
        (unwind-protect
             (flet ((getval (slot-name)
                      (cffi:foreign-slot-value envelope '(:struct amqp-envelope-t) slot-name)))
               (let ((channel (getval 'channel))
                     (consumer-tag (bytes->string (getval 'consumer-tag)))
                     (delivery-tag (getval 'delivery-tag))
                     (exchange (bytes->string (getval 'exchange)))
                     (routing-key (bytes->string (getval 'routing-key))))
                 (values channel consumer-tag delivery-tag exchange routing-key)))
          (amqp-destroy-envelope envelope))))))

(defmacro with-connection ((conn) &body body)
  (let ((conn-sym (gensym "CONN-")))
    `(let ((,conn-sym (new-connection)))
       (unwind-protect
            (let ((,conn ,conn-sym))
              ,@body)
         (destroy-connection ,conn-sym)))))

(defun send-batch (conn queue-name)
  (basic-publish conn 1 "amq.direct" queue-name #(97 98 99 10)))

(defun test-send ()
  (with-connection (conn)
    (let ((socket (tcp-socket-new conn)))
      (socket-open socket "localhost" 5672)
      (login-sasl-plain conn "/" "guest" "guest")
      (channel-open conn 1)
      (send-batch conn "foo"))))

(defun recv-loop (conn)
  (amqp-maybe-release-buffers conn)
  (consume-message conn))

(defun test-recv ()
  (with-connection (conn)
    (let ((socket (tcp-socket-new conn)))
      (socket-open socket "localhost" 5672)
      (login-sasl-plain conn "/" "guest" "guest")
      (channel-open conn 1)
      (let ((queue-name (queue-declare conn 1 :auto-delete t :queue "foo")))
        (queue-bind conn 1 queue-name "amq.direct" "foo")
        (basic-consume conn 1 queue-name)
        (recv-loop conn)))))
