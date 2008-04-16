(in-package :blog)

(defview user-grid-view (:type grid :inherit-from '(:scaffold user)))
(defview user-data-view (:type data :inherit-from '(:scaffold user)))
(defview user-form-view (:type form :inherit-from '(:scaffold user)))

(defview post-grid-view (:type grid :inherit-from '(:scaffold post)))
(defview post-data-view (:type data :inherit-from '(:scaffold post)))
(defview post-form-view (:type form :inherit-from '(:scaffold post)))
