
(in-package :weblocks)

(export '(navigation render-navigation-menu init-navigation make-navigation))

(defwidget navigation (selector)
  ()
  (:documentation "The navigation widget can act as a menu controls, a
  tabbed control, etc. It is a convenience combination of the selector
  widget and a menu snippet."))

(defgeneric render-navigation-menu (obj &rest args)
  (:documentation
   "Renders HTML menu for the navigation widget.")
  (:method ((obj navigation) &rest args)
    (declare (ignore args))
    (render-menu (mapcar (lambda (orig-pane)
			   (let ((pane (car (selector-mixin-canonicalize-pane orig-pane))))
			     (cons (pane-info-label pane)
				   (make-webapp-uri 
				    (if (eq (selector-mixin-default-pane obj) orig-pane)
					"/"
					(compose-uri-tokens-to-url (pane-info-uri-tokens pane)))))))
			 (selector-mixin-panes obj))
		 :selected-uri "baz"
		 :header (if (widget-name obj)
			      (humanize-name (widget-name obj))
			      "Navigation")
		 :empty-message "No navigation entries")))

(defmethod render-widget-body ((obj navigation) &rest args)
  (call-next-method)
  (apply #'render-navigation-menu obj args))

(defmethod widget-public-dependencies ((obj navigation))
  (append (list (public-file-relative-path :stylesheet "menu"))
	  (call-next-method)))

(defun init-navigation (obj &rest args)
  "A helper function to create a navigation widget

ex:

\(init-navigation
   \"test1\" (make-instance ...)
   \"test2\" (make-instance ...)"
  (loop
     for count from 1
     for x in args
     for y in (cdr args)
     when (oddp count)
     do (push-end `(,(attributize-name x) . ,y) (selector-mixin-panes obj)))
  obj)

(defun make-navigation (name &rest args)
  "Instantiates 'navigation' widget via 'make-instance' and forwards
it along with 'args' to 'init-navigation'."
  (let ((nav (make-instance 'navigation :name name)))
    (apply #'init-navigation nav args)
    nav))

