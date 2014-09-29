(defpackage :cl-rabbit
  (:use :cl)
  (:documentation "CFFI-based interface to RabbitMQ")
  (:export #:tcp-socket-new
           #:socket-open
           #:login-sasl-plain
           #:channel-open
           #:consume-message
           #:queue-declare
           #:queue-bind
           #:basic-consume))
