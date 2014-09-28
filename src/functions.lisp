(in-package :cl-rabbit)

(cffi:define-foreign-library librabbitmq
  (:unix "librabbitmq.so"))

(cffi:use-foreign-library librabbitmq)

(cffi:defctype amqp-connection-state-t :pointer)
(cffi:defctype amqp-socket-t-ptr :pointer)

(cffi:defcfun ("amqp_cstring_bytes" amqp-cstring-bytes) (:struct amqp-bytes-t)
  (cstr :string))

(cffi:defcfun ("amqp_get_rpc_reply" amqp-get-rpc-reply) (:struct amqp-rpc-reply-t)
  (state amqp-connection-state-t))

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

(cffi:defcfun ("amqp_channel_open" amqp-channel-open) (:pointer (:struct amqp-channel-open-ok-t))
  (state amqp-connection-state-t)
  (channel amqp-channel-t))

(cffi:defcfun ("amqp_basic_publish" amqp-basic-publish) :int
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (exchange (:struct amqp-bytes-t))
  (routing-key (:struct amqp-bytes-t))
  (mandatory amqp-boolean-t)
  (immediate amqp-boolean-t)
  (properties :pointer)
  (body (:struct amqp-bytes-t)))
