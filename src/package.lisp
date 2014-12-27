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
           #:queue-unbind
           #:basic-consume
           #:basic-publish
           #:with-connection
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
           #:rabbitmq-error
           #:exchange-declare
           #:exchange-delete
           #:exchange-bind
           #:exchange-unbind
           #:new-connection
           #:destroy-connection
           #:channel-flow
           #:message/properties))

(defpackage :cl-rabbit.examples
  (:use :cl :cl-rabbit)
  (:documentation "Examples for cl-rabbit"))
