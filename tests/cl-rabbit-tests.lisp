(in-package :cl-rabbit.tests)

(declaim (optimize (speed 0) (safety 3) (debug 3)))

(defmacro define-rabbitmq-test ((name conn &optional socket) &body body)
  (check-type name symbol)
  (check-type conn (or symbol null))
  (let ((socket-sym (gensym "SOCKET-")))
    `(fiveam:test ,name
       (with-connection (,conn)
         (let ((,socket-sym (tcp-socket-new ,conn)))
           (socket-open ,socket-sym "localhost" 5672)
           (login-sasl-plain ,conn "/" "guest" "guest")
           (channel-open ,conn 1)
           ,(if socket
                `(let ((,socket ,socket-sym)) ,@body)
                `(progn ,@body)))))))

(fiveam:test version-test
  (let ((version (version)))
    (fiveam:is (stringp version))
    (fiveam:is (plusp (length version)))))

(define-rabbitmq-test (connect-test conn)
  (fiveam:is (not (null conn))))

(define-rabbitmq-test (declare-queue-test conn)
  (let ((name (queue-declare conn 1 :durable t :auto-delete t)))
    (fiveam:is (stringp name))
    (fiveam:is (plusp (length name)))))
