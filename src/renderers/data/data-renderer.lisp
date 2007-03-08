;;;; Generic data renderer
(in-package :weblocks)

(defmethod render-data-header (obj)
  (with-html-output (*weblocks-output-stream*)
    (fmt "<div class=\"data ~A\">~%"
	 (attributize-name (object-class-name obj)))
    (loop for i from 1 to 3
          for attr = (format nil "extra-top-~A" i)
       do (htm (:div :class attr "&nbsp;")))
    (:h1 (:span :class "action" "Viewing:&nbsp;")
	 (:span :class "object" (str (humanize-name (object-class-name obj)))))))

(defmethod render-data-slot-object-inline (obj slot-name (slot-value standard-object) &rest args)
  (format *weblocks-output-stream* "~%<!-- Rendering ~A -->~%" (attributize-name slot-name))
  (apply #'render-data slot-value :inlinep t args)
  (format *weblocks-output-stream* "~%"))

(defmethod render-data-slot-object-reference (obj slot-name (slot-value standard-object) &rest args)
  (apply #'render-data-slot obj slot-name (object-name slot-value) args))

(defmethod render-data-slot (obj slot-name (slot-value standard-object) &rest args)
  (if (render-slot-inline-p obj slot-name)
      (apply #'render-data-slot-object-inline obj slot-name slot-value args)
      (apply #'render-data-slot-object-reference obj slot-name slot-value args)))

(defmethod render-data-slot (obj slot-name slot-value &rest args)
  (with-html-output (*weblocks-output-stream*)
    (:li (:h2 (str (humanize-name slot-name)) ":")
	 (apply #'render-data slot-value args))))

(defmethod render-data-pre-slots (obj)
  (format *weblocks-output-stream* "<ul>~%"))

(defmethod render-data-post-slots (obj)
  (format *weblocks-output-stream* "</ul>~%"))

(defmethod render-data-footer (obj)
  (with-html-output (*weblocks-output-stream*)
    (loop for i from 1 to 3
          for attr = (format nil "extra-bottom-~A" i)
       do (htm (:div :class attr "&nbsp;")))
  (format *weblocks-output-stream* "</div>")))

; slot-names is a list of slots. If hidep is t, only the slots in
; slot-names will be displayed, otherwise the slots in slot-names will
; be hidden and all other slots will be displayed. If observe-order-p
; is true, slots will be displayed in the order they appear in the
; list. This option has effect only with hidep is true. If
; slot-names are an association list, slots will be renamed according
; to the values in the list. This option takes effect only if hidep
; is true.
(defmethod render-data ((obj standard-object) &rest keys &key inlinep &allow-other-keys)
  (if (not inlinep) (render-data-header obj))
  (if (not inlinep) (render-data-pre-slots obj))
  (let ((keys-copy (copy-list keys)))
    (remf keys-copy :inlinep)
    (mapc (lambda (slot)
	    (apply #'render-data-slot obj (cdr slot) (get-slot-value obj (car slot)) keys))
	  (apply #'object-visible-slots obj keys-copy)))
  (if (not inlinep) (render-data-post-slots obj))
  (if (not inlinep) (render-data-footer obj))
  *weblocks-output-stream*)

(defmethod render-data (obj &rest keys &key inlinep &allow-other-keys)
  (with-html-output (*weblocks-output-stream*)
    (:span (str obj)))
  *weblocks-output-stream*)

