(in-package :cl-rabbit)

(cffi:define-foreign-library librabbitmq
  (:unix "librabbitmq.so"))

(cffi:use-foreign-library librabbitmq)

(cffi:defctype amqp-socket-t :pointer)

(cffi:defcfun ("amqp_socket_open" amqp-socket-open) :int
  (self (:pointer amqp-socket-t))
  (host (:string))
  (port :int))
