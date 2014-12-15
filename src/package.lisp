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
           #:basic-consume
           #:basic-publish
           #:with-connection
           #:maybe-release-buffers
           #:message/body
           #:envelope/channel
           #:envelope/consumer-tag
           #:envelope/delivery-tag
           #:envelope/exchange
           #:envelope/routing-key
           #:envelope/message
           #:envelope
           #:message
           #:rabbitmq-server-error
           #:rabbitmq-error))

(defpackage :cl-rabbit.examples
  (:use :cl :cl-rabbit)
  (:documentation "Examples for cl-rabbit"))
