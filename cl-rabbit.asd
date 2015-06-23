(cl:eval-when (:load-toplevel :execute)
  (asdf:operate 'asdf:load-op 'cffi-grovel))

(asdf:defsystem :cl-rabbit
  :name "cl-rabbit"
  :author "Elias Martenson <lokedhs@gmail.com>"
  :license "MIT"
  :description "Simple RabbitMQ interface for Common Lisp using CFFI"
  :depends-on (:cffi
               :cffi-libffi
               :alexandria
               :babel
               :cl-ppcre
               :bordeaux-threads)
  :components ((:module src
                        :serial t
                        :components ((:file "package")
                                     (cffi-grovel:grovel-file "grovel")
                                     (:file "functions")
                                     (:file "misc")
                                     (:file "amqp")
                                     (:file "async")))))
