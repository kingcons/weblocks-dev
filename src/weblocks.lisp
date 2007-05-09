;;; Code shared accross the entire weblocks framework
(defpackage #:weblocks
  (:use :cl :c2mop :metabang.utilities :moptilities :hunchentoot :cl-who)
  (:documentation
   "Weblocks is a Common Lisp framework that eases the pain of
web application development. It achieves its goals by
standardizing on various libraries, providing flexible and
extensible generic renderers, and exposing a unique widget-based
approach to maintaining UI state.

You can use the following starting points to dive into the
documentation:

Generic functions 'render-data', 'render-form', 'render-table'."))

(in-package :weblocks)

(export '(*weblocks-output-stream* *current-navigation-url* with-html
	  reset-sessions str server-type server-version))

(defparameter *weblocks-output-stream* nil
  "Output stream for Weblocks framework created for each request
and available to code executed within a request as a special
variable. All html should be rendered to this stream.")

(defparameter *current-navigation-url* nil
  "Always contains a navigation URL at the given point in rendering
  cycle. This is a special variable modified by the navigation
  controls during rendering so that inner controls can determine their
  location in the application hierarchy.")

(defmacro with-html (&body body)
  "A wrapper around cl-who with-html-output macro."
  `(with-html-output (*weblocks-output-stream* nil :indent nil)
     ,@body))

(defun server-type ()
  "Hunchentoot")

(defun server-version ()
  hunchentoot::*hunchentoot-version*)
