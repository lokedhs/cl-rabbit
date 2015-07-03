(in-package :cl-rabbit.tests)

(declaim (optimize (speed 0) (safety 3) (debug 3)))

(defun make-random-name ()
  (with-output-to-string (s)
    (write-string "cl-rabbit-test-" s)
    (loop
       repeat 20
       do (write-char (code-char (+ (random (1+ (- (char-code #\z) (char-code #\a)))) (char-code #\a))) s))))

(defmacro with-rabbitmq-socket ((conn &optional socket) &body body)
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
        (fiveam:is (eql (cl-rabbit::rabbitmq-server-error/method condition) cl-rabbit::amqp-channel-close-method))))
    (channel-open conn 1)
    (let ((q (queue-declare conn 1 :exclusive t :auto-delete t)))
      (ensure-queue q))))
