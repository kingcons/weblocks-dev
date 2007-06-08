
(in-package :weblocks-test)

;;; test with-data-header
(deftest-html with-data-header-1
    (with-data-header *joe* (lambda () nil))
  #.(data-header-template nil '(nil)
			  :postslots nil))

;;; test render-data-slot
(deftest-html render-data-slot-1
    (render-data-slot *joe* 'first-name "Joe")
  (:li :class "first-name"
       (:span :class "label"
	      "First Name:&nbsp;")
       (:span :class "value"
	      "Joe")))

(deftest-html render-data-slot-2
    (render-data-slot *joe* 'address-ref *home-address*)
  (:li :class "address-ref"
       (:span :class "label"
	      "Address:&nbsp;")
       (:span :class "value"
	      "Address")))

(deftest-html render-data-slot-3
    (render-data-slot *joe* 'education *some-college*)
  (htm
   (:li :class "university"
	(:span :class "label" "University:&nbsp;")
	(:span :class "value" "Bene Gesserit University"))
   (:li :class "graduation-year"
	(:span :class "label" "Graduation Year:&nbsp;")
	(:span :class "value" "2000"))))

;;; test render-data
(deftest-html render-data-1
    (render-data "test")
  (:span :class "value" "test"))

(deftest-html render-data-2
    (render-data *joe* :preslots-fn (lambda (obj &rest keys)
							  (with-html
							    (:div "test1")))
		       :postslots-fn (lambda (obj &rest keys)
				       (with-html
					 (:div "test2"))))
  #.(data-header-template nil
     '((:li :class "name" (:span :class "label" "Name:&nbsp;") (:span :class "value" "Joe"))
       (:li :class "manager" (:span :class "label" "Manager:&nbsp;") (:span :class "value" "Jim")))
     :preslots '((:div "test1"))
     :postslots '((:div "test2"))))

(deftest-html render-data-3
    (render-data *joe* :slots '(address-ref))
  #.(data-header-template nil
     '((:li :class "name" (:span :class "label" "Name:&nbsp;") (:span :class "value" "Joe"))
       (:li :class "address-ref" (:span :class "label" "Address:&nbsp;") (:span :class "value" "Address"))
       (:li :class "manager" (:span :class "label" "Manager:&nbsp;") (:span :class "value" "Jim")))
     :postslots nil))

(deftest-html render-data-4
    (render-data *joe* :slots '(education))
  #.(data-header-template nil
     '((:li :class "name" (:span :class "label" "Name:&nbsp;") (:span :class "value" "Joe"))
       (:li :class "university" (:span :class "label" "University:&nbsp;")
	(:span :class "value" "Bene Gesserit University"))
       (:li :class "graduation-year"
	(:span :class "label" "Graduation Year:&nbsp;") (:span :class "value" "2000"))
       (:li :class "manager" (:span :class "label" "Manager:&nbsp;") (:span :class "value" "Jim")))
     :postslots nil))

(deftest-html render-data-5
    (render-data *joe* :slots '((name . nickname)))
  #.(data-header-template nil
     '((:li :class "name" (:span :class "label" "Nickname:&nbsp;") (:span :class "value" "Joe"))
       (:li :class "manager" (:span :class "label" "Manager:&nbsp;") (:span :class "value" "Jim")))
     :postslots nil))

(deftest-html render-data-6
    (render-data "test" :highlight ".s")
  (:span :class "value" "t<strong>es</strong>t"))
