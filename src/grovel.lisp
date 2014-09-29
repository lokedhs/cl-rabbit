(in-package :cl-rabbit)

(include "amqp.h")
(include "amqp_framing.h")
(include "amqp_tcp_socket.h")

(constant (*amqp-version-major* "AMQP_VERSION_MAJOR"))
(constant (*amqp-version-minor* "AMQP_VERSION_MINOR"))
(constant (*amqp-version-patch* "AMQP_VERSION_PATCH"))
(constant (*amqp-version-is-release* "AMQP_VERSION_IS_RELEASE"))

(ctype size-t "size_t")

(ctype amqp-boolean-t "amqp_boolean_t")
(ctype amqp-method-number-t "amqp_method_number_t")
(ctype amqp-channel-t "amqp_channel_t")
(ctype amqp-flags-t "amqp_flags_t")
(ctype uint8-t "uint8_t")
(ctype uint32-t "uint32_t")
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

(cstruct amqp-table-t "amqp_table_t"
         (num-entries "num_entries" :type :int)
         (entries "entries" :type :pointer))

(cstruct amqp-channel-open-ok-t "amqp_channel_open_ok_t"
         (channel-id "channel_id" :type (:struct amqp-bytes-t)))

(cstruct amqp-queue-declare-ok-t "amqp_queue_declare_ok_t"
         (queue "queue" :type (:struct amqp-bytes-t))
         (message-count "message_count" :type uint32-t)
         (consumer-count "consumer_count" :type uint32-t))

(cstruct amqp-basic-consume-ok-t "amqp_basic_consume_ok_t"
         (consumer-tag "consumer_tag" :type (:struct amqp-bytes-t)))

(cstruct amqp-basic-properties-t "amqp_basic_properties_t"
         #+nil(flags "_flags" :type amqp-flags-t)
         (content-type "content_type" :type (:struct amqp-bytes-t))
         (content-encoding "content_encoding" :type (:struct amqp-bytes-t))
         #+nil (headers "headers")
         (delivery-mode "delivery_mode" :type uint8-t)
         (priority "priority" :type uint8-t)
         (correlation-id "correlation_id" :type (:struct amqp-bytes-t))
         (reply-to "reply_to" :type (:struct amqp-bytes-t))
         (expiration "expiration" :type (:struct amqp-bytes-t))
         (message_id "message_id" :type (:struct amqp-bytes-t))
         (timestamp "timestamp" :type uint64-t)
         (type "type" :type (:struct amqp-bytes-t))
         (user_id "user_id" :type (:struct amqp-bytes-t))
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
