(asdf:defsystem :cl-rabbit-tests
  :name "cl-rabbit-tests"
  :author "Elias Martenson <lokedhs@gmail.com>"
  :license "MIT"
  :description "Fiveam testcases for cl-rabbit"
  :depends-on (:cl-rabbit
               :fiveam)
  :components ((:module tests
                        :serial t
                        :components ((:file "package")
                                     (:file "cl-rabbit-tests")))))
