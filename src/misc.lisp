(in-package :cl-rabbit)

(declaim (optimize (speed 0) (safety 3) (debug 3)))

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

(defmacro with-bytes-struct ((symbol value) &body body)
  (let ((value-sym (gensym "VALUE-"))
        (buf-sym (gensym "BUF-")))
    `(let ((,value-sym ,value))
       (with-foreign-buffer-from-byte-array (,buf-sym ,value-sym)
         (let ((,symbol (list 'len (array-dimension ,value-sym 0)
                              'bytes ,buf-sym)))
           ,@body)))))

(defun bytes->array (bytes)
  (let ((pointer (getf bytes 'bytes))
        (length (getf bytes 'len)))
    (unless (and pointer length)
      (error "Argument does not contain the bytes and len fields"))
    (convert-to-bytes (cffi:convert-from-foreign pointer (list :array :unsigned-char length)))))

(defun bytes->string (bytes)
  (babel:octets-to-string (bytes->array bytes) :encoding :utf-8))

(defmacro with-bytes-string ((symbol string) &body body)
  (alexandria:with-gensyms (fn value a string-sym)
    `(let ((,string-sym ,string))
       (labels ((,fn (,a) (let ((,symbol ,a)) ,@body)))
         (if (and ,string-sym (plusp (length ,string-sym)))
             (with-bytes-struct (,value (babel:string-to-octets ,string-sym :encoding :utf-8))
               (,fn ,value))
             (,fn amqp-empty-bytes))))))

(defmacro with-bytes-strings ((&rest definitions) &body body)
  (if definitions
      `(with-bytes-string ,(car definitions)
         (with-bytes-strings ,(cdr definitions)
           ,@body))
      `(progn ,@body)))

(defun call-with-timeval (fn time)
  (if time
      (cffi:with-foreign-objects ((native-timeout '(:struct timeval)))
        (multiple-value-bind (secs microsecs) (truncate time 1000000)
          (setf (cffi:foreign-slot-value native-timeout '(:struct timeval) 'tv-sec) secs)
          (setf (cffi:foreign-slot-value native-timeout '(:struct timeval) 'tv-usec) microsecs)
          (funcall fn native-timeout)))
      (funcall fn (cffi-sys:null-pointer))))

(defmacro with-foreign-timeval ((symbol time) &body body)
  (alexandria:with-gensyms (arg-sym)
    `(call-with-timeval #'(lambda (,arg-sym) (let ((,symbol ,arg-sym)) ,@body)) ,time)))

(defun call-with-amqp-table (fn values)
  (let ((length (length values))
        (allocated-values nil))

    (unwind-protect
         (cffi:with-foreign-objects ((table '(:struct amqp-table-t))
                                     (content '(:struct amqp-table-entry-t) length))
           (loop
              for (key . value) in values
              for i from 0
              for entryptr = (cffi:mem-aptr content '(:struct amqp-table-entry-t) i)
              do (let* ((key-as-utf (babel:string-to-octets key :encoding :utf-8))
                        (keyptr (array-to-foreign-char-array key-as-utf)))
                   (push keyptr allocated-values)
                   (setf (cffi:foreign-slot-value entryptr '(:struct amqp-table-entry-t) 'key)
                         (list 'len (array-dimension key-as-utf 0) 'bytes keyptr))
                   (etypecase value
                     (string (let* ((val-utf (babel:string-to-octets value :encoding :utf-8))
                                    (val-ptr (array-to-foreign-char-array val-utf)))
                               (push val-ptr allocated-values)
                               (setf (cffi:foreign-slot-value
                                      (cffi:foreign-slot-value entryptr '(:struct amqp-table-entry-t) 'value)
                                      '(:struct amqp-field-value-t)
                                      'kind)
                                     (char-code #\x))
                               (setf (cffi:foreign-slot-value
                                      (cffi:foreign-slot-value entryptr '(:struct amqp-table-entry-t) 'value)
                                      '(:struct amqp-field-value-t)
                                      'bytes)
                                     val-ptr))))))
           (setf (cffi:foreign-slot-value table '(:struct amqp-table-t) 'num-entries) length)
           (setf (cffi:foreign-slot-value table '(:struct amqp-table-t) 'entries) content)
           (funcall fn table))

      ;; Unwind form
      (dolist (ptr allocated-values)
        (cffi:foreign-free ptr)))))

(defmacro with-amqp-table ((table values) &body body)
  (alexandria:with-gensyms (values-sym fn)
    `(let ((,values-sym ,values))
       (labels ((,fn (,table) ,@body))
         (if ,values-sym
             (call-with-amqp-table #',fn ,values-sym)
             (,fn amqp-empty-table))))))

(defmacro print-unreadable-safely ((&rest slots) object stream &body body)
  "A version of PRINT-UNREADABLE-OBJECT and WITH-SLOTS that is safe to use with unbound slots"
  (let ((object-copy (gensym "OBJECT"))
        (stream-copy (gensym "STREAM")))
    `(let ((,object-copy ,object)
           (,stream-copy ,stream))
       (symbol-macrolet ,(mapcar #'(lambda (slot-name)
                                     `(,slot-name (if (and (slot-exists-p ,object-copy ',slot-name)
                                                           (slot-boundp ,object-copy ',slot-name))
                                                      (slot-value ,object-copy ',slot-name)
                                                      :not-bound)))
                                 slots)
         (print-unreadable-object (,object-copy ,stream-copy :type t :identity nil)
           ,@body)))))
