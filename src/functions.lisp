(in-package :cl-rabbit)

(cffi:define-foreign-library librabbitmq
  (:darwin "librabbitmq.dylib")
  (:unix "librabbitmq.so"))

(cffi:use-foreign-library librabbitmq)

(cffi:defctype amqp-connection-state-t :pointer)
(cffi:defctype amqp-socket-t-ptr :pointer)

(cffi:defcfun ("amqp_cstring_bytes" amqp-cstring-bytes) (:struct amqp-bytes-t)
  (cstr :string))

(cffi:defcfun ("amqp_error_string2" amqp-error-string2) (:pointer :char)
  (err :int))

(cffi:defcfun ("amqp_get_rpc_reply" amqp-get-rpc-reply) (:struct amqp-rpc-reply-t)
  (state amqp-connection-state-t))

(cffi:defcfun ("amqp_maybe_release_buffers" amqp-maybe-release-buffers) :void
  (state amqp-connection-state-t))

(cffi:defcfun ("amqp_maybe_release_buffers_on_channel" amqp-maybe-release-buffers-on-channel) :void
  (state amqp-connection-state-t)
  (channel amqp-channel-t))

(cffi:defcfun ("amqp_new_connection" amqp-new-connection) amqp-connection-state-t)

(cffi:defcfun ("amqp_connection_close" amqp-connection-close) (:struct amqp-rpc-reply-t)
  (state amqp-connection-state-t)
  (code :int))

(cffi:defcfun ("amqp_destroy_connection" amqp-destroy-connection) :int
  (state amqp-connection-state-t))

(cffi:defcfun ("amqp_tcp_socket_new" amqp-tcp-socket-new) amqp-socket-t-ptr
  (state amqp-connection-state-t))

(cffi:defcfun ("amqp_ssl_socket_new" amqp-ssl-socket-new) amqp-socket-t-ptr
  (state amqp-connection-state-t))

(cffi:defcfun ("amqp_ssl_socket_set_cacert" amqp-ssl-socket-set-cacert) :int
  (socket amqp-socket-t-ptr)
  (cacert (:pointer :char)))

(cffi:defcfun ("amqp_ssl_socket_set_key" amqp-ssl-socket-set-key) :int
  (socket amqp-socket-t-ptr)
  (cert (:pointer :char))
  (key (:pointer :char)))

(cffi:defcfun ("amqp_ssl_socket_set_key_buffer" amqp-ssl-socket-set-key-buffer) :int
  (socket amqp-socket-t-ptr)
  (cert (:pointer :char))
  (key :pointer))

(cffi:defcfun ("amqp_ssl_socket_set_verify" amqp-ssl-socket-set-verify) :void
  (socket amqp-socket-t-ptr)
  (verify amqp-boolean-t))

(cffi:defcfun ("amqp_set_initialize_ssl_library" amqp-set-initialize-ssl-library) :void
  (init amqp-boolean-t))

(cffi:defcfun ("amqp_tcp_socket_set_sockfd" amqp-tcp-socket-set-sockfd) :void
  (self amqp-socket-t-ptr)
  (sockfd :int))

(cffi:defcfun ("amqp_get_sockfd" amqp-get-sockfd) :int
  (state amqp-connection-state-t))

(cffi:defcfun ("amqp_socket_get_sockfd" amqp-socket-get-sockfd) :int
  (self amqp-socket-t-ptr))

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

(cffi:defcfun ("amqp_login_with_properties" amqp-login-sasl-plain-with-properties) (:struct amqp-rpc-reply-t)
  (state amqp-connection-state-t)
  (vhost :string)
  (channel-max :int)
  (frame-max :int)
  (heartbeat :int)
  (properties (:pointer (:struct amqp-table-t)))
  (sasl-method :int #+nil amqp-sasl-method-enum)
  (user :string)
  (password :string))

(cffi:defcfun ("amqp_channel_open" amqp-channel-open) :pointer #+nil(:pointer (:struct amqp-channel-open-ok-t))
  (state amqp-connection-state-t)
  (channel amqp-channel-t))

(cffi:defcfun ("amqp_channel_flow" amqp-channel-flow) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (active (amqp-boolean-t)))

(cffi:defcfun ("amqp_channel_close" amqp-channel-close) (:struct amqp-rpc-reply-t)
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (code :int))

(cffi:defcfun ("amqp_basic_ack" amqp-basic-ack) :int
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (delivery-tag uint64-t)
  (multiple amqp-boolean-t))

(cffi:defcfun ("amqp_basic_get" amqp-basic-get) (:struct amqp-rpc-reply-t)
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (queue (:struct amqp-bytes-t))
  (no-ack amqp-boolean-t))

(cffi:defcfun ("amqp_basic_reject" amqp-basic-reject) :int
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (delivery-tag uint64-t)
  (requeue amqp-boolean-t))

(cffi:defcfun ("amqp_basic_nack" amqp-basic-nack) :int
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (delivery-tag uint64-t)
  (multiple amqp-boolean-t)
  (requeue amqp-boolean-t))

(cffi:defcfun ("amqp_basic_publish" amqp-basic-publish) :int
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (exchange (:struct amqp-bytes-t))
  (routing-key (:struct amqp-bytes-t))
  (mandatory amqp-boolean-t)
  (immediate amqp-boolean-t)
  (properties :pointer)
  (body (:struct amqp-bytes-t)))

(cffi:defcfun ("amqp_basic_qos" amqp-basic-qos) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (prefetch_size uint32-t)
  (prefetch_count uint16-t)
  (global amqp-boolean-t))

(cffi:defcfun ("amqp_exchange_declare" amqp-exchange-declare-0-5) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (exchange (:struct amqp-bytes-t))
  (type (:struct amqp-bytes-t))
  (passive amqp-boolean-t)
  (durable amqp-boolean-t)
  (arguments (:struct amqp-table-t)))

(cffi:defcfun ("amqp_exchange_declare" amqp-exchange-declare-0-6) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (exchange (:struct amqp-bytes-t))
  (type (:struct amqp-bytes-t))
  (passive amqp-boolean-t)
  (durable amqp-boolean-t)
  (auto-delete amqp-boolean-t)
  (internal amqp-boolean-t)
  (arguments (:struct amqp-table-t)))

(cffi:defcfun ("amqp_exchange_delete" amqp-exchange-delete) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (exchange (:struct amqp-bytes-t))
  (if-unused amqp-boolean-t))

(cffi:defcfun ("amqp_exchange_bind" amqp-exchange-bind) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (destination (:struct amqp-bytes-t))
  (source (:struct amqp-bytes-t))
  (routing-key (:struct amqp-bytes-t))
  (arguments (:struct amqp-table-t)))

(cffi:defcfun ("amqp_exchange_unbind" amqp-exchange-unbind) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (destination (:struct amqp-bytes-t))
  (source (:struct amqp-bytes-t))
  (routing-key (:struct amqp-bytes-t))
  (arguments (:struct amqp-table-t)))

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

(cffi:defcfun ("amqp_queue_unbind" amqp-queue-unbind) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (queue (:struct amqp-bytes-t))
  (exchange (:struct amqp-bytes-t))
  (routing-key (:struct amqp-bytes-t))
  (arguments (:struct amqp-table-t)))

(cffi:defcfun ("amqp_queue_purge" amqp-queue-purge) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (queue (:struct amqp-bytes-t)))

(cffi:defcfun ("amqp_queue_delete" amqp-queue-delete) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (queue (:struct amqp-bytes-t))
  (if-unused amqp-boolean-t)
  (if-empty amqp-boolean-t))

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

(cffi:defcfun ("amqp_basic_cancel" amqp-basic-cancel) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (consumer-tag (:struct amqp-bytes-t)))

(cffi:defcfun ("amqp_destroy_envelope" amqp-destroy-envelope) :void
  (envelope (:pointer (:struct amqp-envelope-t))))

(cffi:defcfun ("amqp_data_in_buffer" amqp-data-in-buffer) amqp-boolean-t
  (state amqp-connection-state-t))

(cffi:defcfun ("amqp_frames_enqueued" amqp-frames-enqueued) amqp-boolean-t
  (state amqp-connection-state-t))

(cffi:defcfun ("amqp_simple_wait_frame" amqp-simple-wait-frame) :int
  (state amqp-connection-state-t)
  (decoded-frame (:pointer (:struct amqp-frame-t))))

(cffi:defcfun ("amqp_simple_wait_frame_noblock" amqp-simple-wait-frame-noblock) :int
  (state amqp-connection-state-t)
  (decoded-frame (:pointer (:struct amqp-frame-t)))
  (tv (:pointer (:struct timeval))))

(cffi:defcfun ("amqp_version" amqp-version) :string)

(cffi:defcfun ("amqp_tx_select" amqp-tx-select) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t))

(cffi:defcfun ("amqp_tx_commit" amqp-tx-commit) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t))

(cffi:defcfun ("amqp_tx_rollback" amqp-tx-rollback) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t))

(cffi:defcfun ("amqp_confirm_select" amqp-confirm-select) :pointer
  (state amqp-connection-state-t)
  (channel amqp-channel-t))

(cffi:defcfun ("amqp_send_frame" amqp-send-frame) :int
  (state amqp-connection-state-t)
  (frame (:pointer (:struct amqp-frame-t))))

(cffi:defcfun ("amqp_send_method" amqp-send-method) :int
  (state amqp-connection-state-t)
  (channel amqp-channel-t)
  (id amqp-method-number-t)
  (decoded :pointer))
