#lang racket/base

;;; components/db.rkt
;;; Database component: opens a SQLite connection, runs migrations,
;;; and exposes a call-with-connection helper used throughout the app.

(require db
         component
         racket/contract
         racket/file
         racket/path
         racket/runtime-path
         racket/string)

(provide (contract-out
          [make-db-component  (-> path-string? db-component?)]
          [db-component?      (-> any/c boolean?)]
          [call-with-db       (-> db-component? (-> connection? any) any)]
          [query-rows*        (-> db-component? string? any/c ... (listof vector?))]
          [query-row*         (-> db-component? string? any/c ... vector?)]
          [query-maybe-row*   (-> db-component? string? any/c ... (or/c vector? #f))]
          [query-exec*        (-> db-component? string? any/c ... void?)]))

(define-runtime-path migrations-dir "../migrations")

;; ---- Component definition --------------------------------------------------

(struct db-component (path conn)
  #:transparent)

(define (make-db-component db-path)
  (define conn (sqlite3-connect #:database db-path #:mode 'create))
  ;; Enable WAL mode for better concurrent read performance.
  (query-exec conn "PRAGMA journal_mode=WAL;")
  (query-exec conn "PRAGMA foreign_keys=ON;")
  (run-migrations! conn)
  (db-component db-path conn))

;; Register with Koyo's component lifecycle so it can be stopped cleanly.
(define-component db-component
  #:stop (lambda (c) (disconnect (db-component-conn c))))

;; ---- Migration runner ------------------------------------------------------

(define (run-migrations! conn)
  ;; Ensure a simple schema_versions table exists.
  (query-exec conn
    "CREATE TABLE IF NOT EXISTS schema_migrations (
       filename TEXT PRIMARY KEY,
       applied_at TEXT NOT NULL DEFAULT (datetime('now'))
     );")
  ;; Find .sql files in migrations/, sorted lexicographically.
  (define files
    (sort (directory-list migrations-dir #:build? #t)
          (lambda (a b)
            (string<? (path->string (file-name-from-path a))
                      (path->string (file-name-from-path b))))))
  (for ([f files]
        #:when (equal? (path-get-extension f) #".sql"))
    (define fname (path->string (file-name-from-path f)))
    (define already-applied?
      (not (empty?
            (query-rows conn
              "SELECT 1 FROM schema_migrations WHERE filename = ?;"
              fname))))
    (unless already-applied?
      (define sql (file->string f))
      ;; Execute each statement separated by ";" individually.
      (for ([stmt (string-split sql ";")])
        (define trimmed (string-trim stmt))
        (unless (string=? trimmed "")
          (query-exec conn trimmed)))
      (query-exec conn
        "INSERT INTO schema_migrations (filename) VALUES (?);"
        fname)
      (printf "Migration applied: ~a~n" fname))))

;; ---- Query helpers ---------------------------------------------------------
;;
;; These wrap the raw db library so callers don't need to reach into
;; the component struct themselves.

(define (call-with-db dbc proc)
  (proc (db-component-conn dbc)))

(define (query-rows* dbc sql . args)
  (apply query-rows (db-component-conn dbc) sql args))

(define (query-row* dbc sql . args)
  (apply query-row (db-component-conn dbc) sql args))

(define (query-maybe-row* dbc sql . args)
  (apply query-maybe-row (db-component-conn dbc) sql args))

(define (query-exec* dbc sql . args)
  (apply query-exec (db-component-conn dbc) sql args)
  (void))
