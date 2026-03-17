#lang racket/base

;;; components/db.rkt
;;; Opens a SQLite connection, runs migrations on startup,
;;; and provides simple query helpers used throughout the app.
;;; No component lifecycle machinery — connection is held for the
;;; lifetime of the process, which is fine for a single-process app.

(require db
         racket/contract
         racket/file
         racket/path
         racket/runtime-path
         racket/string
         racket/list)

(provide (contract-out
          [make-db-component    (-> (or/c path-string? symbol?) db-component?)]
          [db-component?        (-> any/c boolean?)]
          [query-rows*          (-> db-component? string? any/c ... (listof vector?))]
          [query-row*           (-> db-component? string? any/c ... vector?)]
          [query-maybe-row*     (-> db-component? string? any/c ... (or/c vector? #f))]
          [query-exec*          (-> db-component? string? any/c ... void?)]))

(define-runtime-path migrations-dir "../migrations")

;; ---- Data type -------------------------------------------------------------

(struct db-component (conn) #:transparent)

;; ---- Constructor -----------------------------------------------------------

(define (make-db-component db-path)
  (define memory? (eq? db-path 'memory))
  (define conn
    (sqlite3-connect
     #:database (if memory? ":memory:" db-path)
     #:mode 'create))
  (unless memory?
    (query-exec conn "PRAGMA journal_mode=WAL;"))
  (query-exec conn "PRAGMA foreign_keys=ON;")
  (run-migrations! conn)
  (db-component conn))

;; ---- Migration runner ------------------------------------------------------

(define (strip-inline-comments sql)
  (regexp-replace* #rx"--[^\n]*" sql ""))

(define (run-migrations! conn)
  (query-exec conn
              "CREATE TABLE IF NOT EXISTS schema_migrations (
       filename TEXT PRIMARY KEY,
       applied_at TEXT NOT NULL DEFAULT (datetime('now'))
     );")
  (define files
    (sort (directory-list migrations-dir #:build? #t)
          (lambda (a b)
            (string<? (path->string (file-name-from-path a))
                      (path->string (file-name-from-path b))))))
  (for ([f files]
        #:when (equal? (path-get-extension f) #".sql"))
    (define fname (path->string (file-name-from-path f)))
    (define already-applied?
      (not (null?
            (query-rows conn
                        "SELECT 1 FROM schema_migrations WHERE filename = ?;"
                        fname))))
    (unless already-applied?
      (define sql (strip-inline-comments (file->string f)))
      (for ([stmt (string-split sql ";")])
        (define trimmed (string-trim stmt))
        (unless (string=? trimmed "")
          (query-exec conn trimmed)))
      (query-exec conn
                  "INSERT INTO schema_migrations (filename) VALUES (?);"
                  fname)
      (printf "Migration applied: ~a~n" fname))))

;; ---- Query helpers ---------------------------------------------------------

(define (query-rows* dbc sql . args)
  (apply query-rows (db-component-conn dbc) sql args))

(define (query-row* dbc sql . args)
  (apply query-row (db-component-conn dbc) sql args))

(define (query-maybe-row* dbc sql . args)
  (apply query-maybe-row (db-component-conn dbc) sql args))

(define (query-exec* dbc sql . args)
  (apply query-exec (db-component-conn dbc) sql args)
  (void))