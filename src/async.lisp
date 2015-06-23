(in-package :cl-rabbit.async)

(defclass channel ()
  ((connection    :type connection
                  :initarg :connection
                  :documentation "The underlying connection object")
   (channel-index :type integer
                  :initarg :channel
                  :documentation "The channel index"))
  (:documentation "A representation of an AMQL channel"))

(defun start-async-loop ()
  )

(defun start-async-thread ()
  )
