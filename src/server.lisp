
(in-package :weblocks)

(export '(start-weblocks stop-weblocks compute-public-files-path
	  *public-files-path* defwebapp ajax-request-p pure-request-p))

(defvar *weblocks-server* nil
  "If the server is started, bound to hunchentoot server
  object. Otherwise, nil.")

(defparameter *render-debug-toolbar* nil
  "A global flag that defines whether the debug toolbar should be
  rendered. Normally set to true when weblocks is started in debug
  mode.")

(defun start-weblocks (&key debug (port 8080))
  "Starts weblocks framework hooked into Hunchentoot server. Set
':debug' keyword to true in order for stacktraces to be shown to
the client."
  (if debug
      (setf *render-debug-toolbar* t)
      (setf *render-debug-toolbar* nil))
  (when debug
    (setf *show-lisp-errors-p* t)
    (setf *show-lisp-backtraces-p* t))
  (when (null *weblocks-server*)
    (setf *session-cookie-name* "weblocks-session")
    (setf *weblocks-server* (start-server :port port))))

(defun stop-weblocks ()
  "Stops weblocks."
  (if (not (null *weblocks-server*))
      (progn
	(reset-sessions)
	(stop-server *weblocks-server*)
	(setf *weblocks-server* nil))))

(defun compute-public-files-path (asdf-system-name)
  "Computes the directory of public files. The function uses the
following protocol: it finds the '.asd' file of the system specified
by 'asdf-system-name', goes up one directory, and goes into 'pub'."
  (merge-pathnames
   (make-pathname :directory '(:relative :up "pub"))
   (make-pathname :directory
		  (pathname-directory (asdf:system-definition-pathname
				       (asdf:find-system asdf-system-name))))))

(defparameter *public-files-path*
  (compute-public-files-path :weblocks)
  "Must be set to a directory on the filesystem that contains public
files that should be available via the webserver (images, stylesheets,
javascript files, etc.) Modify this directory to set the location of
your files. Points to the weblocks' 'pub' directory by default.")

(setf *dispatch-table*
      (append (list (lambda (request)
		      (funcall (create-folder-dispatcher-and-handler "/pub/" *public-files-path*)
			       request))
		    (create-prefix-dispatcher "/" 'handle-client-request))
	      *dispatch-table*))

(defvar *webapp-name* nil
  "The name of the currently running web application. See
'defwebapp' for more details.")

(defun defwebapp (name)
  "Sets the application name (the *webapp-name* variable). 'name'
must be a symbol. This symbol will later be used to find a
package that defined 'init-user-session' - a function responsible
for the web application setup.

'init-user-session' must be defined by weblocks client in the
same package as 'name'. This function will accept a single
parameter - a composite widget at the root of the
application. 'init-user-session' is responsible for adding
initial widgets to this composite."
  (check-type name symbol)
  (setf *webapp-name* name))

(defun ajax-request-p ()
  "Detects if the current request was initiated via AJAX by looking
for 'X-Requested-With' http header. This function expects to be called
in a dynamic hunchentoot environment."
  (header-in "X-Requested-With"))

(defun pure-request-p ()
  "Detects if the current request is declared as 'pure', i.e. affects
no widgets or internal application state, but merely is a request for
information. Such requests simply return the result of the function
that represents the action and are used by some AJAX operations to
retreive information (suggest block, etc). When such requests are
satisfied, the actions have access to the session, the widgets, and
all other parameters. However, none of the callbacks (see
*on-pre-request*) are executed, no widgets are sent to the client,
etc."
  (string-equal (get-parameter "pure") "true"))

(defun session-name-string-pair ()
  "Returns a session name and string suitable for URL rewriting. This
pair is passed to JavaScript because web servers don't normally do URL
rewriting in JavaScript code."
  (if (and *rewrite-for-session-urls*
	   (null (cookie-in *session-cookie-name*))
	   (hunchentoot::session-cookie-value))
      (format nil "~A=~A"
	      (url-encode *session-cookie-name*)
	      (url-encode (hunchentoot::session-cookie-value)))
      ""))
