(in-package :cl-rabbit)

(defun fail-if-null (ptr)
  (when (cffi-sys:null-pointer-p ptr)
    (error "Failed"))
  ptr)

(defun verify-status (status)
  (unless (= status (cffi:foreign-enum-value 'amqp-status-enum :amqp-status-ok))
    (error "Failed: ~a" status)))

(defun new-connection ()
  (fail-if-null (amqp-new-connection)))

(defun destroy-connection (state)
  (verify-status (amqp-destroy-connection state)))

(defun tcp-socket-new (connection)
  (fail-if-null (amqp-tcp-socket-new connection)))

(defun socket-open (socket host port)
  (check-type socket cffi:foreign-pointer)
  (check-type host string)
  (check-type port alexandria:positive-integer)
  (verify-status (amqp-socket-open socket host port)))

(defun login-sasl-plain (state vhost user password &key (channel-max 0) (frame-max 131072) (heartbeat 0))
  (let ((reply (amqp-login-sasl-plain state vhost
                                      channel-max frame-max
                                      heartbeat :amqp-sasl-method-plain user password)))
    (unless (= (getf reply 'reply-type) (cffi:foreign-enum-value 'amqp-response-type-enum :amqp-response-normal))
      (error "Illegal response from login"))))

(defun test-send ()
  (let ((conn (new-connection)))
    (unwind-protect
         (let ((socket (tcp-socket-new conn)))
           (socket-open socket "localhost" 5672)
           (login-sasl-plain conn "/" "guest" "guest"))
      (destroy-connection conn))))
