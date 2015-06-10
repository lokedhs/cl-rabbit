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

(fiveam:test version-test
  (let ((version (version)))
    (fiveam:is (stringp version))
    (fiveam:is (plusp (length version)))))

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
