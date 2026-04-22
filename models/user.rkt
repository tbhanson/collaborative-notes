#lang racket/base

;;; models/user.rkt
;;; User lookup and password verification.
;;; Password hashing uses Argon2id via crypto-lib (libsodium).



(require crypto
         crypto/all
         db
         racket/contract
         racket/match
         "../components/db.rkt")

(provide (contract-out
          [user?               (-> any/c boolean?)]
          [user-id             (-> user? exact-integer?)]
          [user-name           (-> user? string?)]
          [user-display        (-> user? string?)]
          [get-user-by-id      (-> db-component? exact-integer? (or/c user? #f))]
          [get-user-by-name    (-> db-component? string? (or/c user? #f))]
          [list-users          (-> db-component? (listof user?))]
          [check-password      (-> db-component? string? string? (or/c user? #f))]
          [set-password!       (-> db-component? exact-integer? string? void?)]))

;; Use OpenSSL (libcrypto) for password hashing.
(crypto-factories (list libcrypto-factory))

(struct user (id name display) #:transparent)

(define (row->user row)
  (match row
    [(vector id name display) (user id name display)]))

;; ---- Queries ---------------------------------------------------------------

(define (get-user-by-id dbc id)
  (define row (query-maybe-row* dbc
    "SELECT id, name, display_name FROM users WHERE id = ?;" id))
  (and row (row->user row)))

(define (get-user-by-name dbc name)
  (define row (query-maybe-row* dbc
    "SELECT id, name, display_name FROM users WHERE name = ?;" name))
  (and row (row->user row)))

(define (list-users dbc)
  (map row->user
       (query-rows* dbc
         "SELECT id, name, display_name FROM users ORDER BY display_name;")))

;; ---- Password management ---------------------------------------------------

(define (hash-password plaintext)
  (pwhash '(pbkdf2 hmac sha256)
          (string->bytes/utf-8 plaintext)
          '((iterations 310000))))

(define (verify-password plaintext stored-hash)
  (pwhash-verify #f
                 (string->bytes/utf-8 plaintext)
                 stored-hash))

;; Set or update a user's password.
(define (set-password! dbc uid plaintext)
  (define hash (hash-password plaintext))
  (query-exec* dbc
    "UPDATE users SET password_hash = ? WHERE id = ?;"
    hash uid)
  (void))

;; Look up a user by name and verify their password.
;; Returns the user struct on success, #f on failure.
(define (check-password dbc name plaintext)
  (define row (query-maybe-row* dbc
    "SELECT id, name, display_name, password_hash FROM users WHERE name = ?;"
    name))
  (and row
       (match row
         [(vector id uname display stored-hash)
          (and (not (sql-null? stored-hash))
               (verify-password plaintext stored-hash)
               (user id uname display))])))
