(defpackage #:weblocks-postmodern
  (:use :cl :postmodern :weblocks)
  (:shadowing-import-from :postmodern #:text)
  (:shadowing-import-from :weblocks #:commit-transaction)
  (:documentation
   "A driver for weblocks backend store API that connects to Postmodern."))

(in-package :weblocks-postmodern)

(export '())

(defvar *transactions* (make-hash-table))
(defvar *nested-transaction-behavior* :ignore
  "Should be one of :warn, :error or :ignore.
Defines how the system responds when an attempt is made
to nest transactions.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Initialization/finalization ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defmethod open-store ((store-type (eql :postmodern)) &rest args)
  (setf *default-store* (apply #'connect args))
  (setf *database* *default-store*))

(defmethod close-store ((store database-connection))
  (when (eq *default-store* store)
    (disconnect *default-store*)
    (setf *default-store* nil)
    (setf *database* nil)))

(defmethod clean-store ((store database-connection))
  (dolist (table (list-tables))
    (query (:delete-from table)))
  ;; TODO: Fix sequence handling.
  ;; Not presently dropped as they're used implicitly by postmodern for IDs.
  ;; (dolist (seq (list-sequences))
  ;; (query (:drop-sequence seq)))
  (dolist (view (list-views))
    (query (:drop-view view))))

(defmethod store-thread-setup ((store database-connection))
  (with-slots (database user password host) store
    (connect database user password host :pooled-p t)))

(defmethod store-thread-teardown ((store database-connection))
  (disconnect store))

(defmethod use-thread-hooks-p ((store database-connection))
  (declare (ignore store))
  '*database*)


;;;;;;;;;;;;;;;;;;;;
;;; Transactions ;;;
;;;;;;;;;;;;;;;;;;;;
(defmethod begin-transaction ((store database-connection))
  (let* ((thread (bordeaux-threads:current-thread))
	 (transaction (gethash thread *transactions*)))
    ;; Postgres doesn't support nested transactions
    ;; so ensure we're not in a transaction first
    ;; TODO: Support this via Savepoints/postmodern:with-savepoint
    (if transaction
	(progn
	  (ecase *nested-transaction-behavior*
	    (:warn
	       (warn "Could not initiate nested transaction."))
	    (:ignore
	       nil)
	    (:error
	       (error "Could not initiate nested transaction.")))
	  (incf (cdr (gethash thread *transactions*))))
	(progn
	  (setf (gethash thread *transactions*)
		(cons (make-instance 'postmodern::transaction-handle) 0))
	  (execute "BEGIN")))))

(defmethod commit-transaction ((store database-connection))
  (let* ((thread (bordeaux-threads:current-thread))
	 (transaction (gethash thread *transactions*)))
    (if (zerop (cdr transaction))
	(progn
	  (postmodern:commit-transaction (car transaction))
	  (setf (gethash thread *transactions*) nil))
	(decf (cdr (gethash thread *transactions*))))))

(defmethod rollback-transaction ((store database-connection))
  (let* ((thread (bordeaux-threads:current-thread))
	 (transaction (gethash thread *transactions*)))
    (if (zerop (cdr transaction))
	(progn
	  (abort-transaction (car transaction))
	  (setf (gethash thread *transactions*) nil))
	(decf (cdr (gethash thread *transactions*))))))

(defmethod dynamic-transaction ((store database-connection) proc)
  (with-transaction ()
    (funcall proc)))

(defmethod use-dynamic-transaction-p ((store database-connection))
  (declare (ignore store))
  nil)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Creating and deleting persistent objects ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defmethod persist-object ((store database-connection) object &key)
  (if (gethash (bordeaux-threads:current-thread) *transactions*)
      (save-dao/transaction object)
      (save-dao object)))

(defmethod delete-persistent-object ((store database-connection) object)
  (delete-dao object))

(defmethod delete-persistent-object-by-id ((store database-connection) class-name object-id)
  (delete-dao (get-dao class-name object-id)))


;;;;;;;;;;;;;
;;; Utils ;;;
;;;;;;;;;;;;;
(defmethod class-id-slot-name ((class dao-class))
  ;; Returns a list of the column names which compose the primary key.
  (dao-keys class))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Querying persistent objects ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defmethod find-persistent-object-by-id ((store database-connection) class-name object-id)
  (get-dao class-name object-id))

(defmethod find-persistent-objects ((store database-connection) class-name
				    &key order-by range where
				    &allow-other-keys)
  (let* ((base-expr `(:select '* :from ,(dao-table-name class-name)
                              ,@(when where (list :where where))))
	 (order-expr (or `(,@(when order-by
			       `(:order-by ,base-expr ,(car order-by)))) base-expr))
	 (sql-expr (or `(,@(when range
			     `(:limit ,order-expr ,(cdr range) ,(car range)))) order-expr)))
    (query-dao class-name (sql-compile sql-expr))))

(defmethod count-persistent-objects ((store database-connection) class-name
				     &key where &allow-other-keys)
  (let ((sql-expr `(:select (:count '*) :from ,(dao-table-name class-name)
			    ,@(when where (list :where where)))))
    (query (sql-compile sql-expr) :single)))
