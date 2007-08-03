
(in-package :weblocks)

(export '(*on-ajax-complete-scripts* *uri-tokens*
	  *current-page-description* refresh-request-p initial-request-p))

(defgeneric handle-client-request ()
  (:documentation
   "This method handles each request as it comes in from the
server. It is a hunchentoot handler and has access to all hunchentoot
dynamic variables. The default implementation executes a user
action (if any), prepares the navigation controls using
'apply-uri-to-navigation', and renders the main composite wrapped in
HTML provided by 'render-page'. If the request is an AJAX request,
only the dirty widgets are rendered into a JSON data structure. It
also invokes user supplied 'init-user-session' on the first request
that has no session setup.

'handle-client-request' immediately returns '+http-not-found+' if it
sees a mime type on the script name (it doesn't handle what could be
files because these mess with callback functions and break some
widgets that depend on them).

Additionally, on the first request a session is created and a client
is forced to redirect. At this point if the cookie is sent, session
information is removed from the URL, otherwise the URL is left in
tact. This is done so that session information appears on the URL for
clients that don't support cookies (this way AJAX requests followed by
a refresh will work).

This function also manages lists of callback functions and calls them
at different points before and after request. See 'request-hook'.

Override this method (along with :before and :after specifiers to
customize behavior)."))

(defmethod handle-client-request ()
  (when (hunchentoot::mime-type (script-name))
    (setf (return-code) +http-not-found+)
    (throw 'handler-done nil))
  (when (null *session*)
    (when (get-request-action-name)
      (error "Cannot invoke action ~A. The session has timed out." (get-request-action-name)))
    (start-session)
    (setf (session-value 'last-request-uri) :none)
    (redirect (request-uri)))
  (let ((*request-hook* (make-instance 'request-hooks)))
    (declare (special *request-hook*))
    (when (null (session-value 'root-composite))
      (let ((root-composite (make-instance 'composite :name "root")))
	(when *render-debug-toolbar*
	  (initialize-debug-actions))
	(funcall (symbol-function (find-symbol (symbol-name '#:init-user-session)
					       (symbol-package *webapp-name*)))
		 root-composite)
	(setf (session-value 'root-composite) root-composite))
      (when (cookie-in *session-cookie-name*)
	(redirect (remove-session-from-uri (request-uri)))))

    (let ((*weblocks-output-stream* (make-string-output-stream))
	  (*uri-tokens* (tokenize-uri (request-uri)))
	  (*current-navigation-url* "/") *dirty-widgets*
	  *on-ajax-complete-scripts* *page-public-dependencies*
	  *current-page-description*)
      (declare (special *weblocks-output-stream* *current-navigation-url* *dirty-widgets*
			*on-ajax-complete-scripts* *uri-tokens* *page-public-dependencies*
			*current-page-description*))
      (when (pure-request-p)
	(throw 'handler-done (eval-action)))
      (eval-hook :pre-action)
      (eval-action)
      (eval-hook :post-action)
      (eval-hook :pre-render)
      (if (ajax-request-p)
	  (render-dirty-widgets)
	  (progn
	    (apply-uri-to-navigation *uri-tokens*
				     (find-navigation-widget (session-value 'root-composite)))
	    ; we need to render widgets before the boilerplate HTML
	    ; that wraps them in order to collect a list of script and
	    ; stylesheet dependencies.
	    (render-widget (session-value 'root-composite))
	    ; set page title if it isn't already set
	    (when (and (null *current-page-description*)
		       (last *uri-tokens*))
	      (setf *current-page-description* (humanize-name (last-item *uri-tokens*))))
	    ; render page will wrap the HTML already rendered to
	    ; *weblocks-output-stream* with necessary boilerplate HTML
	    (render-page)))
      (eval-hook :post-render)
      (unless (ajax-request-p)
	(setf (session-value 'last-request-uri) *uri-tokens*))
      (get-output-stream-string *weblocks-output-stream*))))

(defun eval-action ()
  "Evaluates the action that came with the request."
  (safe-apply (get-request-action) (alist->plist (request-parameters))))

(defun remove-session-from-uri (uri)
  "Removes the session info from a URI."
  (let ((path (puri:uri-path (puri:parse-uri uri))))
    (loop for x in (get-parameters)
       when (not (string-equal (car x) *session-cookie-name*))
       do (setf path (url-rewrite:add-get-param-to-url path (car x) (cdr x))))
    path))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Below is code that implements friendly URLs ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun apply-uri-to-navigation (tokens navigation-widget)
  "Takes URI tokens and applies them one by one to navigation widgets
in order to allow for friendly URLs. The URLs are basically intimately
linked to navigation controls to simulate document resources on the
server."
  (when (null tokens)
    (reset-navigation-widgets navigation-widget)
    (return-from apply-uri-to-navigation))
  (if (and navigation-widget (pane-exists-p navigation-widget (car tokens)))
      (progn
	(setf (slot-value navigation-widget 'current-pane) (car tokens))
	(apply-uri-to-navigation (cdr tokens)
				 (find-navigation-widget (current-pane-widget navigation-widget))))
      (setf (return-code) +http-not-found+)))

(defun find-navigation-widget (comp)
  "Given a composite 'comp', returns the first navigation widget
contained in 'comp' or its children."
  (when (null comp)
    (return-from find-navigation-widget))
  (when (typep comp 'navigation)
    (return-from find-navigation-widget comp))
  (car (flatten (remove-if #'null
			   (mapcar (lambda (w)
				     (typecase w
				       (navigation w)
				       (composite (find-navigation-widget w))
				       (otherwise nil)))
				   (composite-widgets comp))))))

(defun reset-navigation-widgets (nav)
  "Resets all navigation widgets from 'nav' down, using
'reset-current-pane'."
  (unless (null nav)
    (reset-current-pane nav)
    (reset-navigation-widgets (find-navigation-widget (current-pane-widget nav)))))

(defun tokenize-uri (uri)
  "Tokenizes a URI into a list of elements.

ex:
\(tokenize-uri \"/hello/world/blah\\test\\hala/world?hello=5;blah=7\"
=> (\"hello\" \"world\" \"blah\" \"test\" \"hala\" \"world\")"
  (remove-if (curry #'string-equal "")
	     (cl-ppcre:split "[/\\\\]" (cl-ppcre:regex-replace "\\?.*" uri ""))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; End of friendly URL code ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun render-dirty-widgets ()
  "Renders widgets that have been marked as dirty into a JSON
association list. This function is normally called by
'handle-client-request' to service AJAX requests."
  (declare (special *dirty-widgets* *weblocks-output-stream*
		    *on-ajax-complete-scripts*))
  (setf (header-out "X-JSON")
	(format nil "{\"widgets\":~A,\"on-load\":~A}"
		(encode-json-alist-to-string
		 (mapcar (lambda (w)
			   (cons
			    (widget-name w)
			    (progn
			      (render-widget w :inlinep t)
			      (get-output-stream-string *weblocks-output-stream*))))
			 *dirty-widgets*))
		(encode-json-to-string *on-ajax-complete-scripts*)))
  ;; We need something in the response for Safari to evaluate JSON
  (format *weblocks-output-stream* " "))

(defun refresh-request-p ()
  "Determines if a request is a result of the user invoking a browser
refresh function. Note that a request will not be considered a refresh
if there is an action involved (even if the user hits refresh)."
  (declare (special *uri-tokens*))
  (and
   (null (get-request-action))
   (equalp *uri-tokens* (session-value 'last-request-uri))))

(defun initial-request-p ()
  "Returns true if the request is the first request for the session."
  (equalp (session-value 'last-request-uri) :none))
