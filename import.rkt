#lang racket/base

;;; import.rkt
;;; Import entries from a TSV file into the database.
;;; TSV format (with header row):
;;;   title  body  phonetic  date
;;; All columns after title are optional.
;;; Date should be YYYY-MM-DD; defaults to today if absent or empty.
;;; Idempotent: entries whose title already exists (and is not deleted)
;;; are skipped rather than duplicated.
;;;
;;; Usage:
;;;   racket import.rkt import.tsv
;;;   racket import.rkt import.tsv tim        (specify importing user, default: tim)
;;;   DATABASE_PATH=/var/lib/... racket import.rkt import.tsv

(require db
         racket/file
         racket/string
         racket/match
         "components/db.rkt"
         "models/user.rkt")

;; ---- Config ----------------------------------------------------------------

(define db-path
  (or (getenv "DATABASE_PATH") "family-glossary.db"))

(define args (current-command-line-arguments))

(unless (>= (vector-length args) 1)
  (displayln "Usage: racket import.rkt <file.tsv> [username]")
  (exit 1))

(define tsv-file  (vector-ref args 0))
(define username  (if (> (vector-length args) 1)
                      (vector-ref args 1)
                      "tim"))

;; ---- Helpers ---------------------------------------------------------------

(define (non-empty s)
  (and s
       (let ([t (string-trim s)])
         (and (not (string=? t "")) t))))

(define (parse-row fields)
  (define (col n) (non-empty (and (> (length fields) n) (list-ref fields n))))
  (values (col 0) (col 1) (col 2) (col 3)))

;; ---- Main ------------------------------------------------------------------

(define dbc  (make-db-component db-path))
(define user (get-user-by-name dbc username))

(unless user
  (printf "Error: no user '~a' found in database.~n" username)
  (exit 1))

(define uid (user-id user))
(define lines (file->lines tsv-file))

;; Skip header row and blank lines.
(define data-lines
  (filter (lambda (l) (not (string=? (string-trim l) "")))
          (cdr lines)))

(define imported 0)
(define skipped  0)

(for ([line data-lines])
  (define fields (string-split line "\t"))
  (define-values (title body phonetic date) (parse-row fields))
  (cond
    [(not title)
     (printf "SKIP (no title): ~s~n" line)
     (set! skipped (add1 skipped))]
    [else
     ;; Idempotency check: skip if a non-deleted entry with this title exists.
     (define existing
       (query-maybe-row* dbc
         "SELECT id FROM entries WHERE title = ? AND deleted_at IS NULL;"
         title))
     (cond
       [existing
        (printf "SKIP (already exists): ~a~n" title)
        (set! skipped (add1 skipped))]
       [else
        (define created-at (or date (substring (number->string (current-seconds)) 0 10)))
        (define ts (string-append created-at " 00:00:00"))
        (query-exec* dbc
          "INSERT INTO entries (title, body, phonetic, created_by, created_at)
           VALUES (?, ?, ?, ?, ?);"
          title
          (or body     sql-null)
          (or phonetic sql-null)
          uid
          ts)
        (define new-id
          (vector-ref (query-row* dbc "SELECT last_insert_rowid();") 0))
        (query-exec* dbc
          "INSERT INTO entry_changes (entry_id, changed_by, field, old_value, new_value, changed_at)
           VALUES (?, ?, 'title', NULL, ?, ?);"
          new-id uid title ts)
        (when body
          (query-exec* dbc
            "INSERT INTO entry_changes (entry_id, changed_by, field, old_value, new_value, changed_at)
             VALUES (?, ?, 'body', NULL, ?, ?);"
            new-id uid body ts))
        (when phonetic
          (query-exec* dbc
            "INSERT INTO entry_changes (entry_id, changed_by, field, old_value, new_value, changed_at)
             VALUES (?, ?, 'phonetic', NULL, ?, ?);"
            new-id uid phonetic ts))
        (printf "Imported: ~a (~a)~n" title created-at)
        (set! imported (add1 imported))])]))

(printf "~nDone: ~a imported, ~a skipped.~n" imported skipped)
