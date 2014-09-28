(in-package :cl-rabbit)

(defun fail-if-null (ptr)
  (when (cffi-sys:null-pointer-p ptr)
    (error "Failed"))
  ptr)

(defun verify-status (status)
  (unless (= status (cffi:foreign-enum-value 'amqp-status-enum :amqp-status-ok))
    (error "Failed: ~a" status))
  status)

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

(defun channel-open (state channel)
  (fail-if-null (amqp-channel-open state channel)))

(defun basic-publish (state channel exchange routing-key body
                      &key mandatory immediate)
  (check-type state cffi-sys:foreign-pointer)
  (check-type channel integer)
  (check-type exchange string)
  (check-type routing-key string)
  (check-type body array)
  (with-bytes-struct body-val body
    (verify-status (amqp-basic-publish state channel (amqp-cstring-bytes exchange)
                                       (amqp-cstring-bytes routing-key)
                                       (if mandatory 1 0) (if immediate 1 0)
                                       (cffi-sys:null-pointer) body-val))))

(defun send-batch (conn queue-name)
  (basic-publish conn 1 "amq.direct" queue-name #(97 98 99 10)))

(defun test-send ()
  (let ((conn (new-connection)))
    (unwind-protect
         (let ((socket (tcp-socket-new conn)))
           (socket-open socket "localhost" 5672)
           (login-sasl-plain conn "/" "guest" "guest")
           (channel-open conn 1)
           (send-batch conn "foo"))
      (destroy-connection conn))))
