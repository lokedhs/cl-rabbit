cl-rabbit - Common Lisp interface to RabbitMQ
=============================================

Author: Elias Mårtenson, lokedhs@gmail.com

This library is a CFFI-based interface to the RabbitMQ client
libraries with an interface that is designed to be fairly close to the
native C API.

The easiest way to install this library is to download it using
Quicklisp:

```
(ql:quickload :cl-rabbit)
```

Please look at the file `examples.lisp` for a simple example of using
the library.

Please note that the underlying C API is still in beta, which means
that the API itself sometimes undergoes breaking changes. This project
attempts to work around this as well as possible, but there may be
cases where there are incompatibilities. Please let me know if any
problems are seen.
