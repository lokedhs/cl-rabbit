(in-package :cl-rabbit.tests)

(declaim (optimize (speed 0) (safety 3) (debug 3)))

(defun make-random-name ()
  (with-output-to-string (s)
    (write-string "cl-rabbit-test-" s)
    (loop
       repeat 20
       do (write-char (code-char (+ (random (1+ (- (char-code #\z) (char-code #\a)))) (char-code #\a))) s))))

(defmacro with-rabbitmq-socket ((conn &optional socket) &body body)
  (check-type conn symbol)
  (check-type socket (or null symbol))
  (let ((socket-sym (gensym "SOCKET-")))
    `(with-connection (,conn)
       (let ((,socket-sym (tcp-socket-new ,conn)))
         (socket-open ,socket-sym "localhost" 5672)
         (login-sasl-plain ,conn "/" "guest" "guest")
         (channel-open ,conn 1)
         ,(if socket
              `(let ((,socket ,socket-sym)) ,@body)
              `(progn ,@body))))))

(defmacro define-rabbitmq-test ((name conn &optional socket) &body body)
  (check-type name symbol)
  (check-type conn (or symbol null))
  `(fiveam:test ,name
     (with-rabbitmq-socket (conn ,@(if socket (list socket) nil))
       ,@body)))

(defun ensure-queue (queue)
  (fiveam:is (stringp queue))
  (fiveam:is (plusp (length queue))))

(defun ensure-exchange (exchange)
  (fiveam:is (stringp exchange))
  (fiveam:is (plusp (length exchange))))

(fiveam:test version-test
  (let ((version (version)))
    (fiveam:is-true (stringp version))
    (fiveam:is-true (plusp (length version)))
    (fiveam:is-true (cl-ppcre:scan "^([0-9]+)\\.([0-9]+)\\.([0-9]+)$" version))))

(fiveam:test version-comparator-test
  (fiveam:is-true (cl-rabbit::%check-client-version "0.0.0" 0 0 0))
  (fiveam:is-true (cl-rabbit::%check-client-version "1.0.0" 1 0 0))
  (fiveam:is-false (cl-rabbit::%check-client-version "1.0.0" 1 1 0))
  (fiveam:is-false (cl-rabbit::%check-client-version "1.0.0" 1 1 1))
  (fiveam:is-false (cl-rabbit::%check-client-version "1.3.6" 2 1 1))
  (fiveam:is-true (cl-rabbit::%check-client-version "1.3.6" 1 3 6))
  (fiveam:is-true (cl-rabbit::%check-client-version "1.3.6" 1 3 5))
  (fiveam:is-true (cl-rabbit::%check-client-version "1.3.6" 1 2 6))
  (fiveam:is-true (cl-rabbit::%check-client-version "2.3.6" 1 3 6))
  (fiveam:is-true (cl-rabbit::%check-client-version "2.3.6" 1 5 9))
  (fiveam:is-false (cl-rabbit::%check-client-version "2.3.6" 2 5 0))
  (fiveam:is-false (cl-rabbit::%check-client-version "3.0.9" 3 0 10))
  (fiveam:signals error
    (cl-rabbit::%check-client-version "3.0.9.1" 1 0 0))
  (fiveam:signals error
    (cl-rabbit::%check-client-version "3.0" 1 0 0))
  (fiveam:signals error
    (cl-rabbit::%check-client-version "3" 1 0 0)))

(define-rabbitmq-test (connect-test conn)
  (fiveam:is (not (null conn))))

(define-rabbitmq-test (declare-queue-test conn)
  (let ((name (queue-declare conn 1 :durable t :auto-delete t :exclusive t)))
    (ensure-queue name)))

(fiveam:test declare-named-queue-test
  (let ((name (make-random-name)))
    (with-rabbitmq-socket (conn)
      (let ((queue (queue-declare conn 1 :queue name :durable t :exclusive nil)))
        (ensure-queue queue)
        (fiveam:is (string= queue name))))
    (with-rabbitmq-socket (conn)
      (let ((queue (queue-declare conn 1 :queue name :passive t)))
        (ensure-queue queue)))
    (with-rabbitmq-socket (conn)
      (queue-delete conn 1 name))
    (with-rabbitmq-socket (conn)
      (fiveam:signals cl-rabbit:rabbitmq-server-error
        (queue-declare conn 1 :queue name :passive t)))))

(fiveam:test declare-named-exchange-test
  (let ((name (make-random-name)))
    (with-rabbitmq-socket (conn)
      (exchange-declare conn 1 name "topic"))
    (with-rabbitmq-socket (conn)
      (exchange-declare conn 1 name "topic" :passive t))
    (with-rabbitmq-socket (conn)
      (exchange-delete conn 1 name))
    (with-rabbitmq-socket (conn)
      (fiveam:signals cl-rabbit:rabbitmq-server-error
        (exchange-declare conn 1 name "topic" :passive t)))))

(fiveam:test get-error-message-test
  (with-rabbitmq-socket (conn)
    (handler-case
        (queue-declare conn 1 :queue "nonexistent" :passive t)
      (rabbitmq-server-error (condition)
        (fiveam:is (plusp (rabbitmq-server-error/reply-code condition)))))))

(fiveam:test close-channel-test
 (with-rabbitmq-socket (conn)
   (channel-open conn 2)
   (channel-close conn 2)))

(fiveam:test channel-error-test
  (with-rabbitmq-socket (conn)
    (handler-case
        (queue-declare conn 1 :queue "none" :passive t)
      (rabbitmq-server-error (condition)
        (fiveam:is (eql (cl-rabbit::rabbitmq-server-error/method condition) cl-rabbit::+amqp-channel-close-method+))))
    (channel-open conn 1)
    (let ((q (queue-declare conn 1 :exclusive t :auto-delete t)))
      (ensure-queue q))))

(defun table-equal-p (v1 v2)
  (labels ((valid-byte-value-p (v)
             (and (integerp v) (<= 0 v 255)))
           (check-valid-values (v)
             (loop
                for m across v
                unless (valid-byte-value-p m)
                do (error "Unexpected value in array: ~s" m))))
    (etypecase v1
      (string (equal v1 v2))
      (array (check-valid-values v1)
             (and (arrayp v2)
                  (= (array-rank v1) 1)
                  (= (array-rank v2) 1)
                  (= (length v1) (length v2))
                  (loop
                     for m0 across v1
                     for m1 across v2
                     unless (eql m0 m1)
                     return nil
                     finally (return t))))
      (integer (eql v1 v2))
      (float (< (abs (- v1 v2))
                ;; Epsilon for Standard 64-bit floating point numbers is 1.40129846d-45
                1d-44))
      (null (null v2))
      (list (unless (and (every #'stringp (mapcar #'car v1))
                         (every #'stringp (mapcar #'car v2)))
              (error "Keys in headers should be strings"))
            (and (= (length v1) (length v2))
                 (loop
                    for (snd-h . snd-v) in (sort v1 #'string< :key #'car)
                    for (rec-h . rec-v) in (sort v2 #'string< :key #'car)
                    unless (and (equal snd-h rec-h)
                                (table-equal-p snd-v rec-v))
                    return nil
                    finally (return t)))))))

(fiveam:test message-properties-table-test
  (with-rabbitmq-socket (conn)
    (let ((correlation-id "some-id")
          (send-hdr '(("header0" . "value0")
                      ("header1" . 9)
                      ("header2" . #(1 2 3 4 5 6))
                      ("header3" . 1.2d0)
                      #+nil("header4" . (("inner-header0" . "foo")
                                         ("inner-header1" . 91)
                                         ("inner-header2" . #(9 8 7 6))))
                      ("header5" . #.(expt 2 60))))
          (ex "foo-ex")
          (q (queue-declare conn 1 :exclusive t :auto-delete t)))
      (exchange-declare conn 1 ex "topic" :durable t)
      (queue-bind conn 1 :queue q :exchange ex :routing-key "#")
      (basic-publish conn 1
                     :exchange ex
                     :routing-key "foo"
                     :body "test"
                     :properties `((:correlation-id . ,correlation-id)
                                   (:headers . ,send-hdr)))
      (basic-consume conn 1 q)
      (let ((msg (consume-message conn :timeout 1)))
        (fiveam:is (not (null msg)))
        (let ((properties (message/properties (envelope/message msg))))
          (let ((received-id (assoc :correlation-id properties)))
            (fiveam:is (consp received-id))
            (let ((id-string (cdr received-id)))
              (fiveam:is (equal correlation-id id-string))))
          (let ((headers (assoc :headers properties)))
            (fiveam:is (consp headers))
            (fiveam:is (table-equal-p send-hdr (cdr headers)))))))))

(fiveam:test commit-transaction-test
  (with-rabbitmq-socket (conn)
    ;; Open two channels and declare an exchange and a queue that
    ;; channel is listening on. Channel 2 sends a transacted message,
    ;; and the test verifies that the message is not delivered until
    ;; the transaction is committed.
    (let ((e "txtest-ex")
          (q "txtest")
          (content "test content"))
      (channel-open conn 2)
      (exchange-declare conn 1 e "topic")
      (queue-declare conn 1 :queue q :auto-delete t)
      (queue-bind conn 1 :queue "txtest" :exchange e :routing-key "#")
      (basic-consume conn 1 q :no-ack t)
      ;; Activate transactions on channel 2
      (tx-select conn 2)
      (basic-publish conn 2 :exchange e :routing-key "x" :body "rollback message")
      (tx-rollback conn 2)
      (basic-publish conn 2 :exchange e :routing-key "x" :body content)
      (handler-case
          (progn
            (consume-message conn :timeout 500000)
            (fiveam:is-false t))
        (rabbitmq-library-error (condition)
          (fiveam:is (eq :amqp-status-timeout (rabbitmq-library-error/error-code condition)))))
      (tx-commit conn 2)
      (let* ((msg (consume-message conn :timeout 500000))
             (recv-text (babel:octets-to-string (message/body (envelope/message msg)))))
        (fiveam:is (equal content recv-text))))))

(fiveam:test confirm-select-success-test
  (with-rabbitmq-socket (conn)
    (channel-open conn 2)
    (confirm-select conn 2)))

(fiveam:test confirm-select-when-channel-in-tx-failure-test
  (fiveam:signals rabbitmq-server-error
    (with-rabbitmq-socket (conn)
    (channel-open conn 2)
    (tx-select conn 2)
    (confirm-select conn 2))))

(fiveam:test simple-wait-frame-publisher-confirms-with-basic-acknowledgment
  (with-rabbitmq-socket (conn)
    (channel-open conn 2)
    (confirm-select conn 2)
    (exchange-declare conn 2 "direct-ex-test" "direct")
    (basic-publish conn
                   2
                   :exchange "direct-ex-test"
                   :routing-key "publisher-test"
                   :body "test publisher confirm")
    (let* ((frame (simple-wait-frame conn)))
      (fiveam:is (typep frame 'method-frame-basic-acknowledgment))
      (fiveam:is (eql (channel frame) 2))
      (fiveam:is (eql (delivery-tag frame) 1))
      (fiveam:is (not (multiplep frame))))))

(fiveam:test simple-wait-frame-no-consumer-for-mandatory-message-publishers-receives-return-header-body-method-frames
  (with-rabbitmq-socket (conn)
    (let* ((exchange "direct-ex-test")
           (routing-key "publisher-test")
           (content "test return method frame"))
      (channel-open conn 2)
      (exchange-declare conn 2 exchange "direct")
      (basic-publish conn
                     2
                     :exchange exchange
                     :routing-key routing-key
                     :mandatory t
                     :body content)
      (let* ((return-method-frame (simple-wait-frame conn))
             (content-header-frame (simple-wait-frame conn))
             (content-body-frame (simple-wait-frame conn)))
        ;; Assert return method frame
        (fiveam:is (typep return-method-frame 'method-frame-basic-return))
        (fiveam:is (eql (channel return-method-frame) 2))
        (fiveam:is (equal (reply-text return-method-frame) "NO_ROUTE"))
        (fiveam:is (equal (reply-code return-method-frame) 312))
        (fiveam:is (equal (exchange return-method-frame) exchange))
        (fiveam:is (equal (routing-key return-method-frame) routing-key))
        ;; Assert content header frame
        (fiveam:is (typep content-header-frame 'content-header-frame))
        (fiveam:is (eql (channel content-header-frame) 2))
        (fiveam:is (eql (class-id content-header-frame) #.cl-rabbit::+amqp-basic-class+))
        (fiveam:is (> (body-size content-header-frame)))
        ;; Assert content body frame
        (fiveam:is (typep content-body-frame 'content-body-frame))
        (fiveam:is (eql (channel content-body-frame) 2))
        (fiveam:is (equal (babel:octets-to-string (body content-body-frame)) content))))))

(fiveam:test simple-wait-frame-consumer-receives-deliver-method-frame
  (with-rabbitmq-socket (conn)
    (exchange-declare conn 1 "direct-ex-test" "direct")
    (queue-declare conn 1 :queue "test-q" :auto-delete t)
    (queue-bind conn
                1
                :queue "test-q"
                :exchange "direct-ex-test"
                :routing-key "deliver-method-frame-test")
    (basic-consume conn 1 "test-q" :no-ack t)
    (channel-open conn 2)
    (basic-publish conn
                   2
                   :exchange "direct-ex-test"
                   :routing-key "deliver-method-frame-test"
                   :mandatory t
                   :body "test receive deliver method frame")
    (let* ((frame (simple-wait-frame conn)))
      (fiveam:is (typep frame 'method-frame-basic-deliver))
      (fiveam:is (eql (channel frame) 1))
      (fiveam:is (not (null (consumer-tag frame))))
      (fiveam:is (eql (delivery-tag frame) 1))
      (fiveam:is (not (redeliveredp frame)))
      (fiveam:is (equal (exchange frame) "direct-ex-test"))
      (fiveam:is (equal (routing-key frame) "deliver-method-frame-test")))))
