#lang racket/base

;;; models/entry.rkt
;;; CRUD for glossary entries.  Every mutating operation also writes
;;; a row to entry_changes so the full audit trail is always current.

(require db
         racket/contract
         racket/list
         racket/match
         racket/string
         "../components/db.rkt")

(provide (contract-out
          [entry?            (-> any/c boolean?)]
          [entry-id          (-> entry? exact-integer?)]
          [entry-title       (-> entry? string?)]
          [entry-body        (-> entry? (or/c string? #f))]
          [entry-phonetic    (-> entry? (or/c string? #f))]
          [entry-created-by  (-> entry? exact-integer?)]
          [entry-created-at  (-> entry? string?)]

          [list-entries      (-> db-component?
                                 #:sort (or/c 'alpha 'date)
                                 #:include-deleted? boolean?
                                 (listof entry?))]
          [get-entry         (-> db-component? exact-integer? (or/c entry? #f))]
          [create-entry!     (-> db-component?
                                 #:title string?
                                 #:body (or/c string? #f)
                                 #:phonetic (or/c string? #f)
                                 #:user-id exact-integer?
                                 exact-integer?)]
          [update-entry!     (-> db-component?
                                 #:id exact-integer?
                                 #:title string?
                                 #:body (or/c string? #f)
                                 #:phonetic (or/c string? #f)
                                 #:user-id exact-integer?
                                 void?)]
          [delete-entry!     (-> db-component?
                                 #:id exact-integer?
                                 #:user-id exact-integer?
                                 void?)]))

;; ---- Data type -------------------------------------------------------------

(struct entry (id title body phonetic created-by created-at) #:transparent)

(define (row->entry row)
  (match row
    [(vector id title body phonetic created-by created-at)
     (entry id
            title
            (if (sql-null? body)     #f body)
            (if (sql-null? phonetic) #f phonetic)
            created-by
            created-at)]))

;; ---- Queries ---------------------------------------------------------------

(define (list-entries dbc #:sort sort-by #:include-deleted? include-deleted?)
  (define where  (if include-deleted? "" "WHERE deleted_at IS NULL"))
  (define order  (case sort-by
                   [(alpha) "ORDER BY lower(title) ASC"]
                   [(date)  "ORDER BY created_at DESC"]))
  (map row->entry
       (query-rows* dbc
                    (string-append
                     "SELECT id, title, body, phonetic, created_by, created_at
            FROM entries "
                     where " " order ";"))))

(define (get-entry dbc id)
  (define row (query-maybe-row* dbc
                                "SELECT id, title, body, phonetic, created_by, created_at
     FROM entries WHERE id = ?;" id))
  (and row (row->entry row)))

;; ---- Mutations + audit trail -----------------------------------------------

(define (create-entry! dbc #:title title #:body body #:phonetic phonetic #:user-id uid)
  (query-exec* dbc
               "INSERT INTO entries (title, body, phonetic, created_by)
     VALUES (?, ?, ?, ?);"
               title
               (or body    sql-null)
               (or phonetic sql-null)
               uid)
  (define new-id
    (vector-ref (query-row* dbc "SELECT last_insert_rowid();") 0))
  ;; Record creation in audit trail.
  (record-change! dbc new-id uid "title"    #f title)
  (when body     (record-change! dbc new-id uid "body"     #f body))
  (when phonetic (record-change! dbc new-id uid "phonetic" #f phonetic))
  new-id)

(define (update-entry! dbc #:id id #:title title #:body body #:phonetic phonetic #:user-id uid)
  (define old (get-entry dbc id))
  (unless old (error 'update-entry! "No entry with id ~a" id))
  ;; Record a change row for each field that actually changed.
  (define (maybe-record! field old-val new-val)
    (define old-s (or old-val ""))
    (define new-s (or new-val ""))
    (unless (string=? old-s new-s)
      (record-change! dbc id uid field old-val new-val)))
  (maybe-record! "title"    (entry-title    old) title)
  (maybe-record! "body"     (entry-body     old) body)
  (maybe-record! "phonetic" (entry-phonetic old) phonetic)
  ;; Perform the actual update.
  (query-exec* dbc
               "UPDATE entries SET title = ?, body = ?, phonetic = ? WHERE id = ?;"
               title
               (or body     sql-null)
               (or phonetic sql-null)
               id)
  (void))

(define (delete-entry! dbc #:id id #:user-id uid)
  (record-change! dbc id uid "deleted_at" #f "deleted")
  (query-exec* dbc
               "UPDATE entries SET deleted_at = datetime('now') WHERE id = ?;" id)
  (void))

;; ---- Internal: audit trail write -------------------------------------------

(define (record-change! dbc entry-id user-id field old-value new-value)
  (query-exec* dbc
               "INSERT INTO entry_changes (entry_id, changed_by, field, old_value, new_value)
     VALUES (?, ?, ?, ?, ?);"
               entry-id
               user-id
               field
               (or old-value sql-null)
               (or new-value sql-null)))
