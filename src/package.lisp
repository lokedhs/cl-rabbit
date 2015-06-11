(defpackage :cl-rabbit
  (:use :cl)
  (:documentation "CFFI-based interface to RabbitMQ")
  (:export #:basic-ack
           #:basic-consume
           #:basic-nack
           #:basic-publish
           #:channel-close
           #:channel-flow
           #:channel-open
           #:consume-message
           #:destroy-connection
           #:envelope
           #:envelope/channel
           #:envelope/consumer-tag
           #:envelope/delivery-tag
           #:envelope/exchange
           #:envelope/message
           #:envelope/routing-key
           #:exchange-bind
           #:exchange-declare
           #:exchange-delete
           #:exchange-unbind
           #:login-sasl-plain
           #:message
           #:message/body
           #:message/properties
           #:new-connection
           #:queue-bind
           #:queue-declare
           #:queue-unbind
           #:rabbitmq-error
           #:rabbitmq-server-error
           #:socket-open
           #:tcp-socket-new
           #:with-connection
           #:version
           #:queue-purge
           #:queue-delete
           #:rabbitmq-library-error))

(defpackage :cl-rabbit.examples
  (:use :cl :cl-rabbit)
  (:documentation "Examples for cl-rabbit"))
