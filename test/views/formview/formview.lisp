
(in-package :weblocks-test)

;;; Test mixin-form-view-field-persist-p
(deftest mixin-form-view-field-persist-p-1
    (mixin-form-view-field-persist-p (make-instance 'mixin-form-view-field
						    :view (defview-anon (:type form :persistp nil))))
  nil)

(deftest mixin-form-view-field-persist-p-2
    (mixin-form-view-field-persist-p (make-instance 'mixin-form-view-field
						    :view (defview-anon (:type form :persistp t))))
  t)

(deftest mixin-form-view-field-persist-p-3
    (mixin-form-view-field-persist-p (make-instance 'mixin-form-view-field
						    :view (defview-anon (:type form :persistp t))
						    :persistp nil))
  nil)

;;; Test form view view-default-field-type
(deftest form-view-view-default-field-type-1
    (view-default-field-type 'form 'mixin)
  mixin-form)

;;; Test render-validation-summary
(deftest-html render-validation-summary-1
    (render-validation-summary (make-instance 'form-view)
			       *joe* nil
			       (list (cons nil "Hello is a required field.")))
  (:div :class "validation-errors-summary"
	(:h2 :class "error-count"
	     "There is 1 validation error:")
	(:ul
	 (:li "Hello is a required field."))))

(deftest-html render-validation-summary-2
    (render-validation-summary (make-instance 'form-view)
			       *joe* nil
			       (list (cons nil "Hello is a required field.")
				     (cons nil "World is a required field.")))
  (:div :class "validation-errors-summary"
	(:h2 :class "error-count"
	     "There are 2 validation errors:")
	(:ul
	 (:li "Hello is a required field.")
	 (:li "World is a required field."))))

(deftest-html render-validation-summary-3
    (render-validation-summary (make-instance 'form-view)
			       *joe* nil
			       nil)
  nil)

;;; Test render-form-view-buttons
(deftest-html render-form-view-buttons-1
    (render-form-view-buttons (make-instance 'form-view)
			      *joe* nil)
  (:div :class "submit"
	(:input :name "submit" :type "submit" :class "submit" :value "Submit"
		:onclick "disableIrrelevantButtons(this);")
	(:input :name "cancel" :type "submit" :class "submit cancel" :value "Cancel"
		:onclick "disableIrrelevantButtons(this);")))

(deftest-html render-form-view-buttons-2
    (render-form-view-buttons (make-instance 'form-view
					     :buttons (list :cancel))
			      *joe* nil)
  (:div :class "submit"
	(:input :name "cancel" :type "submit" :class "submit cancel" :value "Cancel"
		:onclick "disableIrrelevantButtons(this);")))

;;; Test form view with-view-header
(deftest-html form-view-with-view-header-1
    (with-request :get nil
      (with-view-header (make-instance 'form-view
				       :default-action (lambda (&rest args)
							 (declare (ignore args))))
	*joe* nil
	(lambda (&rest args)
	  (declare (ignore args)))))
  #.(form-header-template "abc123"
     '()))

;;; Test form view render-view-field
(deftest-html render-view-field-1
    (render-view-field (make-instance 'form-view-field
				      :slot-name 'name
				      :requiredp t)
		       (make-instance 'form-view)
		       nil
		       (make-instance 'input-presentation)
		       "Joe" *joe*)
  (:li :class "name"
       (:label :class "input"
	       (:span :class "slot-name"
		      (:span :class "extra" "Name:&nbsp;"
			     (:em :class "required-slot" "(required)&nbsp;")))
	       (:input :type "text" :name "name" :value "Joe" :maxlength "40"))))

(deftest-html render-view-field-2
    (let ((field (make-instance 'form-view-field
				:slot-name 'name
				:requiredp t)))
      (render-view-field field
			 (make-instance 'form-view)
			 nil
			 (make-instance 'input-presentation)
			 "Joe" *joe*
			 :validation-errors (list (cons field "Some Error!"))))
  (:li :class "name item-not-validated"
       (:label :class "input"
	       (:span :class "slot-name"
		      (:span :class "extra" "Name:&nbsp;"
			     (:em :class "required-slot" "(required)&nbsp;")))
	       (:input :type "text" :name "name" :value "Joe" :maxlength "40")
	       (:p :class "validation-error"
		   (:em (:span :class "validation-error-heading" "Error:&nbsp;")
			"Some Error!")))))

;;; Test form view render-view-field-value
(deftest-html form-view-render-view-field-value-1
    (render-view-field-value "Joe" (make-instance 'input-presentation)
			     (make-instance 'form-view-field
					    :slot-name 'name)
			     (make-instance 'form-view)
			     nil *joe*)
  (:input :type "text" :name "name" :value "Joe" :maxlength "40"))

(deftest-html form-view-render-view-field-value-2
    (let ((field (make-instance 'form-view-field
				:slot-name 'name)))
      (render-view-field-value "Joe" (make-instance 'input-presentation)
			       field
			       (make-instance 'form-view)
			       nil *joe*
			       :intermediate-values (list (cons field "Jim"))))
  (:input :type "text" :name "name" :value "Jim" :maxlength "40"))

;;; Test form view print-view-field-value
(deftest form-view-print-view-field-value-1
    (print-view-field-value nil (make-instance 'input-presentation)
			    (make-instance 'form-view-field)
			    (make-instance 'form-view) nil nil)
  nil)

;;; Test form-field-intermediate-value
(deftest form-field-intermediate-value-1
    (let ((field (make-instance 'form-view-field)))
      (form-field-intermediate-value field (list (cons 1 2)
						 (cons field 3)
						 (cons 4 5))))
  3 t)

;;; Test form view render-object-view
(deftest-html form-view-render-object-view-1
    (with-request :get nil
      (render-object-view *joe* '(form employee)
			  :action (lambda (&rest args)
				    (declare (ignore args)))))
  #.(form-header-template "abc123"
     '((:li :class "name"
	(:label :class "input"
	 (:span :class "slot-name"
		(:span :class "extra" "Name:&nbsp;"
		       (:em :class "required-slot" "(required)&nbsp;")))
	 (:input :type "text" :name "name" :value "Joe" :maxlength "40")))
       (:li :class "manager"
	(:label :class "input"
	 (:span :class "slot-name"
		(:span :class "extra" "Manager:&nbsp;"))
	 (:input :type "text" :name "manager" :value "Jim" :maxlength "40"))))))
