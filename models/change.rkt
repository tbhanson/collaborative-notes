#lang racket/base

;;; models/change.rkt
;;; Read-only access to the entry_changes audit trail.

(require db
         racket/contract
         racket/match
         "../components/db.rkt")

(provide (contract-out
          [change?             (-> any/c boolean?)]
          [change-id           (-> change? exact-integer?)]
          [change-entry-id     (-> change? exact-integer?)]
          [change-display-name (-> change? string?)]
          [change-changed-at   (-> change? string?)]
          [change-field        (-> change? string?)]
          [change-old-value    (-> change? (or/c string? #f))]
          [change-new-value    (-> change? (or/c string? #f))]
          [list-changes-for-entry (-> db-component? exact-integer? (listof change?))]))

(struct change (id entry-id display-name changed-at field old-value new-value)
  #:transparent)

(define (row->change row)
  (match row
    [(vector id entry-id display-name changed-at field old-val new-val)
     (change id
             entry-id
             display-name
             changed-at
             field
             (if (sql-null? old-val) #f old-val)
             (if (sql-null? new-val) #f new-val))]))

(define (list-changes-for-entry dbc entry-id)
  (map row->change
       (query-rows* dbc
         "SELECT ec.id,
                 ec.entry_id,
                 u.display_name,
                 ec.changed_at,
                 ec.field,
                 ec.old_value,
                 ec.new_value
          FROM entry_changes ec
          JOIN users u ON u.id = ec.changed_by
          WHERE ec.entry_id = ?
          ORDER BY ec.changed_at ASC;"
         entry-id)))
