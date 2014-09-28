(in-package :cl-rabbit)

(defun convert-to-bytes (array)
  (labels ((mk-byte8 (a)
             (let ((result (make-array (length a) :element-type '(unsigned-byte 8))))
               (map-into result #'(lambda (v)
                                    (unless (typep v '(unsigned-byte 8))
                                      (error "Value ~s in input array is not an (UNSIGNED-BYTE 8)" v))
                                    v)
                         array)
               result)))
    (typecase array
      ((simple-array (unsigned-byte 8) (*)) array)
      (t (mk-byte8 array)))))

(defun array-to-foreign-char-array (array)
  (let ((result (convert-to-bytes array)))
    ;; Due to a bug in ABCL, CFFI:CONVERT-TO-FOREIGN cannot be used.
    ;; Until this bug is fixed, let's just use a workaround.
    #-abcl (cffi:convert-to-foreign result (list :array :unsigned-char (length result)))
    #+abcl (let* ((length (length result))
                  (type (list :array :unsigned-char length))
                  (foreign-array (cffi:foreign-alloc type :count length)))
             (loop
                for v across result
                for i from 0
                do (setf (cffi:mem-aref foreign-array :unsigned-char i) v))
             foreign-array)))

(defmacro with-foreign-buffer-from-byte-array ((sym buffer) &body body)
  (let ((s (gensym "FOREIGN-BUFFER-")))
    `(let ((,s (array-to-foreign-char-array ,buffer)))
       (unwind-protect
            (let ((,sym ,s))
              (progn ,@body))
         (cffi:foreign-free ,s)))))

(defmacro with-bytes-struct (symbol value &body body)
  (let ((value-sym (gensym "VALUE-"))
        (buf-sym (gensym "BUF-")))
    `(let ((,value-sym ,value))
       (with-foreign-buffer-from-byte-array (,buf-sym ,value-sym)
         (let ((,symbol (list 'len (array-dimension ,value-sym 0)
                              'bytes ,buf-sym)))
           ,@body)))))
