#lang racket/base

;;; set-password.rkt
;;; Admin script to set or reset a user's password.
;;; Usage:
;;;   racket set-password.rkt <username> <password>
;;;   racket set-password.rkt tim "hunter2"
;;;
;;; Run from the project root directory.

(require racket/cmdline
         "components/db.rkt"
         "models/user.rkt")

(define db-path
  (or (getenv "DATABASE_PATH") "family-glossary.db"))

(define args (current-command-line-arguments))

(unless (= (vector-length args) 2)
  (displayln "Usage: racket set-password.rkt <username> <password>")
  (exit 1))

(define username (vector-ref args 0))
(define password (vector-ref args 1))

(define dbc (make-db-component db-path))
(define user (get-user-by-name dbc username))

(unless user
  (printf "Error: no user found with name '~a'~n" username)
  (printf "Existing users:~n")
  (for ([u (list-users dbc)])
    (printf "  ~a (~a)~n" (user-name u) (user-display u)))
  (exit 1))

(set-password! dbc (user-id user) password)
(printf "Password set for ~a (~a)~n" (user-name user) (user-display user))
