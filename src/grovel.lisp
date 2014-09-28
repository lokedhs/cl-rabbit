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
