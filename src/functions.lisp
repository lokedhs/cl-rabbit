(in-package :cl-rabbit)

(declaim (optimize (speed 0) (safety 3) (debug 3)))

(cffi:define-foreign-library librabbitmq
  (:unix "librabbitmq.so"))

(cffi:use-foreign-library librabbitmq)

(cffi:defctype amqp-connection-state-t :pointer)
(cffi:defctype amqp-socket-t-ptr :pointer)

(cffi:defcfun ("amqp_cstring_bytes" amqp-cstring-bytes) (:struct amqp-bytes-t)
  (cstr :string))

(cffi:defcfun ("amqp_get_rpc_reply" amqp-get-rpc-reply) (:struct amqp-rpc-reply-t)
  (state amqp-connection-state-t))

(cffi:defcfun ("amqp_maybe_release_buffers" amqp-maybe-release-buffers) :void
  (state amqp-connection-state-t))
(cffi:defcfun ("amqp_maybe_release_buffers_on_channel" amqp-maybe-release-buffers-on-channel) :void
  (state amqp-connection-state-t)
  (channel amqp-channel-t))

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

(cffi:defcfun ("amqp_channel_open" amqp-channel-open) :pointer #+nil(:pointer (:struct amqp-channel-open-ok-t))
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

(cffi:defcfun ("amqp_queue_declare" amqp-queue-declare) :pointer #+nil(:pointer (:struct amqp-queue-declare-ok-t))
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (queue (:struct amqp-bytes-t))
  (passive amqp-boolean-t)
  (durable amqp-boolean-t)
  (exclusive amqp-boolean-t)
  (auto-delete amqp-boolean-t)
  (arguments (:struct amqp-table-t)))

(cffi:defcfun ("amqp_queue_bind" amqp-queue-bind) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (queue (:struct amqp-bytes-t))
  (exchange (:struct amqp-bytes-t))
  (routing-key (:struct amqp-bytes-t))
  (arguments (:struct amqp-table-t)))

(cffi:defcfun ("amqp_basic_consume" amqp-basic-consume) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (queue (:struct amqp-bytes-t))
  (consumer-tag (:struct amqp-bytes-t))
  (no-local amqp-boolean-t)
  (no-ack amqp-boolean-t)
  (exclusive amqp-boolean-t)
  (arguments (:struct amqp-table-t)))

(cffi:defcfun ("amqp_consume_message" amqp-consume-message) (:struct amqp-rpc-reply-t)
  (state amqp-connection-state-t)
  (envelope (:pointer (:struct amqp-envelope-t)))
  (timeout (:pointer (:struct timeval)))
  (flags :int))

(cffi:defcfun ("amqp_destroy_envelope" amqp-destroy-envelope) :void
  (envelope (:pointer (:struct amqp-envelope-t))))
