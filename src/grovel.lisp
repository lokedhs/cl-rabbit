(in-package :cl-rabbit)

#+(or freebsd darwin)
(progn
  (include "time.h")
  (include "sys/time.h"))

(cc-flags #+freebsd "-I/usr/local/include")

(include "amqp.h")
(include "amqp_framing.h")
(include "amqp_tcp_socket.h")

(constant (+amqp-version-major+ "AMQP_VERSION_MAJOR"))
(constant (+amqp-version-minor+ "AMQP_VERSION_MINOR"))
(constant (+amqp-version-patch+ "AMQP_VERSION_PATCH"))
(constant (+amqp-version-is-release+ "AMQP_VERSION_IS_RELEASE"))

(constant (+amqp-protocol-version-major+ "AMQP_PROTOCOL_VERSION_MAJOR"))
(constant (+amqp-protocol-version-minor+ "AMQP_PROTOCOL_VERSION_MINOR"))
(constant (+amqp-protocol-version-revision+ "AMQP_PROTOCOL_VERSION_REVISION"))
(constant (+amqp-protocol-port+ "AMQP_PROTOCOL_PORT"))
(constant (+amqp-frame-method+ "AMQP_FRAME_METHOD"))
(constant (+amqp-frame-header+ "AMQP_FRAME_HEADER"))
(constant (+amqp-frame-body+ "AMQP_FRAME_BODY"))
(constant (+amqp-frame-heartbeat+ "AMQP_FRAME_HEARTBEAT"))
(constant (+amqp-frame-min-size+ "AMQP_FRAME_MIN_SIZE"))
(constant (+amqp-frame-end+ "AMQP_FRAME_END"))
(constant (+amqp-reply-success+ "AMQP_REPLY_SUCCESS"))
(constant (+amqp-content-too-large+ "AMQP_CONTENT_TOO_LARGE"))
(constant (+amqp-no-route+ "AMQP_NO_ROUTE"))
(constant (+amqp-no-consumers+ "AMQP_NO_CONSUMERS"))
(constant (+amqp-access-refused+ "AMQP_ACCESS_REFUSED"))
(constant (+amqp-not-found+ "AMQP_NOT_FOUND"))
(constant (+amqp-resource-locked+ "AMQP_RESOURCE_LOCKED"))
(constant (+amqp-precondition-failed+ "AMQP_PRECONDITION_FAILED"))
(constant (+amqp-connection-forced+ "AMQP_CONNECTION_FORCED"))
(constant (+amqp-invalid-path+ "AMQP_INVALID_PATH"))
(constant (+amqp-frame-error+ "AMQP_FRAME_ERROR"))
(constant (+amqp-syntax-error+ "AMQP_SYNTAX_ERROR"))
(constant (+amqp-command-invalid+ "AMQP_COMMAND_INVALID"))
(constant (+amqp-channel-error+ "AMQP_CHANNEL_ERROR"))
(constant (+amqp-unexpected-frame+ "AMQP_UNEXPECTED_FRAME"))
(constant (+amqp-resource-error+ "AMQP_RESOURCE_ERROR"))
(constant (+amqp-not-allowed+ "AMQP_NOT_ALLOWED"))
(constant (+amqp-not-implemented+ "AMQP_NOT_IMPLEMENTED"))
(constant (+amqp-internal-error+ "AMQP_INTERNAL_ERROR"))

(constant (+amqp-connection-start-method+ "AMQP_CONNECTION_START_METHOD"))
(constant (+amqp-connection-start-ok-method+ "AMQP_CONNECTION_START_OK_METHOD"))
(constant (+amqp-connection-secure-method+ "AMQP_CONNECTION_SECURE_METHOD"))
(constant (+amqp-connection-secure-ok-method+ "AMQP_CONNECTION_SECURE_OK_METHOD"))
(constant (+amqp-connection-tune-method+ "AMQP_CONNECTION_TUNE_METHOD"))
(constant (+amqp-connection-tune-ok-method+ "AMQP_CONNECTION_TUNE_OK_METHOD"))
(constant (+amqp-connection-open-method+ "AMQP_CONNECTION_OPEN_METHOD"))
(constant (+amqp-connection-open-ok-method+ "AMQP_CONNECTION_OPEN_OK_METHOD"))
(constant (+amqp-connection-close-method+ "AMQP_CONNECTION_CLOSE_METHOD"))
(constant (+amqp-connection-close-ok-method+ "AMQP_CONNECTION_CLOSE_OK_METHOD"))
(constant (+amqp-connection-blocked-method+ "AMQP_CONNECTION_BLOCKED_METHOD"))
(constant (+amqp-connection-unblocked-method+ "AMQP_CONNECTION_UNBLOCKED_METHOD"))
(constant (+amqp-channel-open-method+ "AMQP_CHANNEL_OPEN_METHOD"))
(constant (+amqp-channel-open-ok-method+ "AMQP_CHANNEL_OPEN_OK_METHOD"))
(constant (+amqp-channel-flow-method+ "AMQP_CHANNEL_FLOW_METHOD"))
(constant (+amqp-channel-flow-ok-method+ "AMQP_CHANNEL_FLOW_OK_METHOD"))
(constant (+amqp-channel-close-method+ "AMQP_CHANNEL_CLOSE_METHOD"))
(constant (+amqp-channel-close-ok-method+ "AMQP_CHANNEL_CLOSE_OK_METHOD"))
(constant (+amqp-access-request-method+ "AMQP_ACCESS_REQUEST_METHOD"))
(constant (+amqp-access-request-ok-method+ "AMQP_ACCESS_REQUEST_OK_METHOD"))
(constant (+amqp-exchange-declare-method+ "AMQP_EXCHANGE_DECLARE_METHOD"))
(constant (+amqp-exchange-declare-ok-method+ "AMQP_EXCHANGE_DECLARE_OK_METHOD"))
(constant (+amqp-exchange-delete-method+ "AMQP_EXCHANGE_DELETE_METHOD"))
(constant (+amqp-exchange-delete-ok-method+ "AMQP_EXCHANGE_DELETE_OK_METHOD"))
(constant (+amqp-exchange-bind-method+ "AMQP_EXCHANGE_BIND_METHOD"))
(constant (+amqp-exchange-bind-ok-method+ "AMQP_EXCHANGE_BIND_OK_METHOD"))
(constant (+amqp-exchange-unbind-method+ "AMQP_EXCHANGE_UNBIND_METHOD"))
(constant (+amqp-exchange-unbind-ok-method+ "AMQP_EXCHANGE_UNBIND_OK_METHOD"))
(constant (+amqp-queue-declare-method+ "AMQP_QUEUE_DECLARE_METHOD"))
(constant (+amqp-queue-declare-ok-method+ "AMQP_QUEUE_DECLARE_OK_METHOD"))
(constant (+amqp-queue-bind-method+ "AMQP_QUEUE_BIND_METHOD"))
(constant (+amqp-queue-bind-ok-method+ "AMQP_QUEUE_BIND_OK_METHOD"))
(constant (+amqp-queue-purge-method+ "AMQP_QUEUE_PURGE_METHOD"))
(constant (+amqp-queue-purge-ok-method+ "AMQP_QUEUE_PURGE_OK_METHOD"))
(constant (+amqp-queue-delete-method+ "AMQP_QUEUE_DELETE_METHOD"))
(constant (+amqp-queue-delete-ok-method+ "AMQP_QUEUE_DELETE_OK_METHOD"))
(constant (+amqp-queue-unbind-method+ "AMQP_QUEUE_UNBIND_METHOD"))
(constant (+amqp-queue-unbind-ok-method+ "AMQP_QUEUE_UNBIND_OK_METHOD"))
(constant (+amqp-basic-qos-method+ "AMQP_BASIC_QOS_METHOD"))
(constant (+amqp-basic-qos-ok-method+ "AMQP_BASIC_QOS_OK_METHOD"))
(constant (+amqp-basic-consume-method+ "AMQP_BASIC_CONSUME_METHOD"))
(constant (+amqp-basic-consume-ok-method+ "AMQP_BASIC_CONSUME_OK_METHOD"))
(constant (+amqp-basic-cancel-method+ "AMQP_BASIC_CANCEL_METHOD"))
(constant (+amqp-basic-cancel-ok-method+ "AMQP_BASIC_CANCEL_OK_METHOD"))
(constant (+amqp-basic-publish-method+ "AMQP_BASIC_PUBLISH_METHOD"))
(constant (+amqp-basic-return-method+ "AMQP_BASIC_RETURN_METHOD"))
(constant (+amqp-basic-deliver-method+ "AMQP_BASIC_DELIVER_METHOD"))
(constant (+amqp-basic-get-method+ "AMQP_BASIC_GET_METHOD"))
(constant (+amqp-basic-get-ok-method+ "AMQP_BASIC_GET_OK_METHOD"))
(constant (+amqp-basic-get-empty-method+ "AMQP_BASIC_GET_EMPTY_METHOD"))
(constant (+amqp-basic-ack-method+ "AMQP_BASIC_ACK_METHOD"))
(constant (+amqp-basic-reject-method+ "AMQP_BASIC_REJECT_METHOD"))
(constant (+amqp-basic-recover-async-method+ "AMQP_BASIC_RECOVER_ASYNC_METHOD"))
(constant (+amqp-basic-recover-method+ "AMQP_BASIC_RECOVER_METHOD"))
(constant (+amqp-basic-recover-ok-method+ "AMQP_BASIC_RECOVER_OK_METHOD"))
(constant (+amqp-basic-nack-method+ "AMQP_BASIC_NACK_METHOD"))
(constant (+amqp-tx-select-method+ "AMQP_TX_SELECT_METHOD"))
(constant (+amqp-tx-select-ok-method+ "AMQP_TX_SELECT_OK_METHOD"))
(constant (+amqp-tx-commit-method+ "AMQP_TX_COMMIT_METHOD"))
(constant (+amqp-tx-commit-ok-method+ "AMQP_TX_COMMIT_OK_METHOD"))
(constant (+amqp-tx-rollback-method+ "AMQP_TX_ROLLBACK_METHOD"))
(constant (+amqp-tx-rollback-ok-method+ "AMQP_TX_ROLLBACK_OK_METHOD"))
(constant (+amqp-confirm-select-method+ "AMQP_CONFIRM_SELECT_METHOD"))
(constant (+amqp-confirm-select-ok-method+ "AMQP_CONFIRM_SELECT_OK_METHOD"))

(constant (+amqp-basic-content-type-flag+ "AMQP_BASIC_CONTENT_TYPE_FLAG"))
(constant (+amqp-basic-content-encoding-flag+ "AMQP_BASIC_CONTENT_ENCODING_FLAG"))
(constant (+amqp-basic-headers-flag+ "AMQP_BASIC_HEADERS_FLAG"))
(constant (+amqp-basic-delivery-mode-flag+ "AMQP_BASIC_DELIVERY_MODE_FLAG"))
(constant (+amqp-basic-priority-flag+ "AMQP_BASIC_PRIORITY_FLAG"))
(constant (+amqp-basic-correlation-id-flag+ "AMQP_BASIC_CORRELATION_ID_FLAG"))
(constant (+amqp-basic-reply-to-flag+ "AMQP_BASIC_REPLY_TO_FLAG"))
(constant (+amqp-basic-expiration-flag+ "AMQP_BASIC_EXPIRATION_FLAG"))
(constant (+amqp-basic-message-id-flag+ "AMQP_BASIC_MESSAGE_ID_FLAG"))
(constant (+amqp-basic-timestamp-flag+ "AMQP_BASIC_TIMESTAMP_FLAG"))
(constant (+amqp-basic-type-flag+ "AMQP_BASIC_TYPE_FLAG"))
(constant (+amqp-basic-user-id-flag+ "AMQP_BASIC_USER_ID_FLAG"))
(constant (+amqp-basic-app-id-flag+ "AMQP_BASIC_APP_ID_FLAG"))
(constant (+amqp-basic-cluster-id-flag+ "AMQP_BASIC_CLUSTER_ID_FLAG"))

(ctype size-t "size_t")
(ctype amqp-boolean-t "amqp_boolean_t")
(ctype amqp-method-number-t "amqp_method_number_t")
(ctype amqp-channel-t "amqp_channel_t")
(ctype amqp-flags-t "amqp_flags_t")
(ctype int8-t "int8_t")
(ctype uint8-t "uint8_t")
(ctype int16-t "int16_t")
(ctype uint16-t "uint16_t")
(ctype int32-t "int32_t")
(ctype uint32-t "uint32_t")
(ctype int64-t "int64_t")
(ctype uint64-t "uint64_t")
(ctype time-t "time_t")
(ctype suseconds-t "suseconds_t")

(cstruct timeval "struct timeval"
         (tv-sec "tv_sec" :type time-t)
         (tv-usec "tv_usec" :type suseconds-t))

(cstruct amqp-method-t "amqp_method_t"
         (id "id" :type amqp-method-number-t)
         (decoded "decoded" :type :pointer))

(cstruct amqp-rpc-reply-t "amqp_rpc_reply_t"
         (reply-type "reply_type" :type :int)
         (reply "reply" :type (:struct amqp-method-t))
         (library-error "library_error" :type :int))

(cstruct amqp-bytes-t "amqp_bytes_t"
         (len "len" :type size-t)
         (bytes "bytes" :type :pointer))

(cstruct amqp-channel-open-ok-t "amqp_channel_open_ok_t"
         (channel-id "channel_id" :type (:struct amqp-bytes-t)))

(cstruct amqp-channel-close-ok-t "amqp_channel_close_ok_t"
         (dummy "dummy" :type :char))

(cstruct amqp-queue-declare-ok-t "amqp_queue_declare_ok_t"
         (queue "queue" :type (:struct amqp-bytes-t))
         (message-count "message_count" :type uint32-t)
         (consumer-count "consumer_count" :type uint32-t))

(cstruct amqp-basic-consume-ok-t "amqp_basic_consume_ok_t"
         (consumer-tag "consumer_tag" :type (:struct amqp-bytes-t)))

(cstruct amqp-frame-t "amqp_frame_t"
         (frame-type "frame_type" :type uint8-t)
         (channel "channel" :type amqp-channel-t)
         (payload-method "payload.method" :type (:struct amqp-method-t))
         (payload-properties-class-id "payload.properties.class_id" :type uint16-t)
         (payload-properties-body-size "payload.properties.body_size" :type uint64-t)
         (payload-properties-decoded "payload.properties.decoded" :type :pointer)
         (payload-properties-raw "payload.properties.raw" :type (:struct amqp-bytes-t))
         (payload-body-fragment "payload.body_fragment" :type (:struct amqp-bytes-t))
         (payload-protocol-header-transport-high "payload.protocol_header.transport_high" :type uint8-t)
         (payload-protocol-header-transport-low "payload.protocol_header.transport_low" :type uint8-t)
         (payload-protocol-header-protocol-version-major "payload.protocol_header.protocol_version_major" :type uint8-t)
         (payload-protocol-header-protocol-version-minor "payload.protocol_header.protocol_version_minor" :type uint8-t))

(cstruct amqp-decimal-t "amqp_decimal_t"
         (decimals "decimals" :type uint8-t)
         (value "value" :type uint32-t))

(cstruct amqp-array-t "amqp_array_t"
         (num-entries "num_entries" :type :int)
         (entries "entries" :type :pointer))

(cstruct amqp-table-t "amqp_table_t"
         (num-entries "num_entries" :type :int)
         (entries "entries" :type :pointer))

(cstruct amqp-field-value-t "amqp_field_value_t"
         (kind "kind" :type uint8-t)
         (value-boolean "value.boolean" :type amqp-boolean-t)
         (value-i8 "value.i8" :type int8-t)
         (value-u8 "value.u8" :type uint8-t)
         (value-i16 "value.i16" :type int16-t)
         (value-u16 "value.u16" :type uint16-t)
         (value-i32 "value.i32" :type uint32-t)
         (value-u32 "value.u32" :type int32-t)
         (value-i64 "value.i64" :type int64-t)
         (value-u64 "value.u64" :type uint64-t)
         (value-f32 "value.f32" :type :float)
         (value-f64 "value.f64" :type :double)
         (value-decimal "value.decimal" :type (:struct amqp-decimal-t))
         (value-bytes "value.bytes" :type (:struct amqp-bytes-t))
         (value-table "value.table" :type (:struct amqp-table-t))
         (value-array "value.array" :type (:struct amqp-array-t)))

(cstruct amqp-table-entry-t "amqp_table_entry_t"
         (key "key" :type (:struct amqp-bytes-t))
         (value "value" :type (:struct amqp-field-value-t)))

(cstruct amqp-basic-properties-t "amqp_basic_properties_t"
         (flags "_flags" :type amqp-flags-t)
         (content-type "content_type" :type (:struct amqp-bytes-t))
         (content-encoding "content_encoding" :type (:struct amqp-bytes-t))
         (headers "headers" :type (:struct amqp-table-t))
         (delivery-mode "delivery_mode" :type uint8-t)
         (priority "priority" :type uint8-t)
         (correlation-id "correlation_id" :type (:struct amqp-bytes-t))
         (reply-to "reply_to" :type (:struct amqp-bytes-t))
         (expiration "expiration" :type (:struct amqp-bytes-t))
         (message-id "message_id" :type (:struct amqp-bytes-t))
         (timestamp "timestamp" :type uint64-t)
         (type "type" :type (:struct amqp-bytes-t))
         (user-id "user_id" :type (:struct amqp-bytes-t))
         (app-id "app_id" :type (:struct amqp-bytes-t))
         (cluster-id "cluster_id" :type (:struct amqp-bytes-t)))

(cstruct amqp-message-t "amqp_message_t"
         (properties "properties" :type (:struct amqp-basic-properties-t))
         (body "body" :type (:struct amqp-bytes-t))
         #+nil(pool "pool" :type amqp-pool-t))

(cstruct amqp-envelope-t "amqp_envelope_t"
         (channel "channel" :type amqp-channel-t)
         (consumer-tag "consumer_tag" :type (:struct amqp-bytes-t))
         (delivery-tag "delivery_tag" :type uint64-t)
         (redelivered "redelivered" :type amqp-boolean-t)
         (exchange "exchange" :type (:struct amqp-bytes-t))
         (routing-key "routing_key" :type (:struct amqp-bytes-t))
         (message "message" :type (:struct amqp-message-t)))

(cstruct amqp-channel-close-t "amqp_channel_close_t"
         (reply-code "reply_code" :type uint16-t)
         (reply-text "reply_text" :type (:struct amqp-bytes-t))
         (class-id "class_id" :type uint16-t)
         (method-id "method_id" :type uint16-t))

(cstruct amqp-connection-close-t "amqp_connection_close_t"
         (reply-code "reply_code" :type uint16-t)
         (reply-text "reply_text" :type (:struct amqp-bytes-t))
         (class-id "class_id" :type uint16-t)
         (method-id "method_id" :type uint16-t))

(cvar ("amqp_empty_table" amqp-empty-table) (:struct amqp-table-t))
(cvar ("amqp_empty_bytes" amqp-empty-bytes) (:struct amqp-bytes-t))

(cenum amqp-sasl-method-enum
       ((:amqp-sasl-method-plain "AMQP_SASL_METHOD_PLAIN")))

(cenum (amqp-status-enum)
       ((:amqp-status-ok "AMQP_STATUS_OK"))
       ((:amqp-status-no-memory "AMQP_STATUS_NO_MEMORY"))
       ((:amqp-status-bad-amqp-data "AMQP_STATUS_BAD_AMQP_DATA"))
       ((:amqp-status-unknown-class "AMQP_STATUS_UNKNOWN_CLASS"))
       ((:amqp-status-unknown-method "AMQP_STATUS_UNKNOWN_METHOD"))
       ((:amqp-status-hostname-resolution-failed "AMQP_STATUS_HOSTNAME_RESOLUTION_FAILED"))
       ((:amqp-status-incompatible-amqp-version "AMQP_STATUS_INCOMPATIBLE_AMQP_VERSION"))
       ((:amqp-status-connection-closed "AMQP_STATUS_CONNECTION_CLOSED"))
       ((:amqp-status-bad-url "AMQP_STATUS_BAD_URL"))
       ((:amqp-status-socket-error "AMQP_STATUS_SOCKET_ERROR"))
       ((:amqp-status-invalid-parameter "AMQP_STATUS_INVALID_PARAMETER"))
       ((:amqp-status-table-too-big "AMQP_STATUS_TABLE_TOO_BIG"))
       ((:amqp-status-wrong-method "AMQP_STATUS_WRONG_METHOD"))
       ((:amqp-status-timeout "AMQP_STATUS_TIMEOUT"))
       ((:amqp-status-timer-failure "AMQP_STATUS_TIMER_FAILURE"))
       ((:amqp-status-heartbeat-timeout "AMQP_STATUS_HEARTBEAT_TIMEOUT"))
       ((:amqp-status-unexpected-state "AMQP_STATUS_UNEXPECTED_STATE"))
       ((:amqp-status-tcp-error "AMQP_STATUS_TCP_ERROR"))
       ((:amqp-status-tcp-socketlib-init-error "AMQP_STATUS_TCP_SOCKETLIB_INIT_ERROR"))
       ((:amqp-status-ssl-error "AMQP_STATUS_SSL_ERROR"))
       ((:amqp-status-ssl-hostname-verify-failed "AMQP_STATUS_SSL_HOSTNAME_VERIFY_FAILED"))
       ((:amqp-status-ssl-peer-verify-failed "AMQP_STATUS_SSL_PEER_VERIFY_FAILED"))
       ((:amqp-status-ssl-connection-failed "AMQP_STATUS_SSL_CONNECTION_FAILED")))

(cenum (amqp-response-type-enum)
       ((:amqp-response-none "AMQP_RESPONSE_NONE"))
       ((:amqp-response-normal "AMQP_RESPONSE_NORMAL"))
       ((:amqp-response-library-exception "AMQP_RESPONSE_LIBRARY_EXCEPTION"))
       ((:amqp-response-server-exception "AMQP_RESPONSE_SERVER_EXCEPTION")))

(cenum (amqp-field-value-kind-t)
       ((:amqp-field-kind-boolean "AMQP_FIELD_KIND_BOOLEAN"))
       ((:amqp-field-kind-i8 "AMQP_FIELD_KIND_I8"))
       ((:amqp-field-kind-u8 "AMQP_FIELD_KIND_U8"))
       ((:amqp-field-kind-i16 "AMQP_FIELD_KIND_I16"))
       ((:amqp-field-kind-u16 "AMQP_FIELD_KIND_U16"))
       ((:amqp-field-kind-i32 "AMQP_FIELD_KIND_I32"))
       ((:amqp-field-kind-u32 "AMQP_FIELD_KIND_U32"))
       ((:amqp-field-kind-i64 "AMQP_FIELD_KIND_I64"))
       ((:amqp-field-kind-u64 "AMQP_FIELD_KIND_U64"))
       ((:amqp-field-kind-f32 "AMQP_FIELD_KIND_F32"))
       ((:amqp-field-kind-f64 "AMQP_FIELD_KIND_F64"))
       ((:amqp-field-kind-decimal "AMQP_FIELD_KIND_DECIMAL"))
       ((:amqp-field-kind-utf8 "AMQP_FIELD_KIND_UTF8"))
       ((:amqp-field-kind-array "AMQP_FIELD_KIND_ARRAY"))
       ((:amqp-field-kind-timestamp "AMQP_FIELD_KIND_TIMESTAMP"))
       ((:amqp-field-kind-table "AMQP_FIELD_KIND_TABLE"))
       ((:amqp-field-kind-void "AMQP_FIELD_KIND_VOID"))
       ((:amqp-field-kind-bytes "AMQP_FIELD_KIND_BYTES")))
