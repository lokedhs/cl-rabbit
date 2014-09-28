(in-package :cl-rabbit)

(cffi:define-foreign-library librabbitmq
  (:unix "librabbitmq.so"))

(cffi:use-foreign-library librabbitmq)

(cffi:defctype amqp-connection-state-t :pointer)
(cffi:defctype amqp-socket-t-ptr :pointer)

(cffi:defcfun ("amqp_new_connection" amqp-new-connection) amqp-connection-state-t)
(cffi:defcfun ("amqp_destroy_connection" amqp-destroy-connection) :int
  (state amqp-connection-state-t))

(cffi:defcfun ("amqp_tcp_socket_new" amqp-tcp-socket-new) amqp-socket-t-ptr
  (state amqp-connection-state-t))
(cffi:defcfun ("amqp_tcp_socket_set_sockfd" amqp-tcp-socket-set-sockfd) :void
  (base amqp-socket-t-ptr)
  (sockfs :int))

(cffi:defcfun ("amqp_socket_open" amqp-socket-open) :int
  (self :pointer)
  (host :string)
  (port :int))

(cffi:defcfun ("amqp_login" amqp-login-sasl-plain) (:struct amqp-rpc-reply-t)
  (state amqp-connection-state-t)
  (vhost :string)
  (channel-max :int)
  (frame-max :int)
  (heartbeat :int)
  (sasl-method amqp-sasl-method-enum)
  (user :string)
  (password :string))
