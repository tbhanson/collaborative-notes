#lang racket/base

;;; models/user.rkt

(require db
         racket/contract
         racket/match
         "../components/db.rkt")

(provide (contract-out
          [user?          (-> any/c boolean?)]
          [user-id        (-> user? exact-integer?)]
          [user-name      (-> user? string?)]
          [user-display   (-> user? string?)]
          [get-user-by-id   (-> db-component? exact-integer? (or/c user? #f))]
          [get-user-by-name (-> db-component? string? (or/c user? #f))]
          [list-users       (-> db-component? (listof user?))]))

(struct user (id name display) #:transparent)

(define (row->user row)
  (match row
    [(vector id name display) (user id name display)]))

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
       (query-rows* dbc "SELECT id, name, display_name FROM users ORDER BY display_name;")))
