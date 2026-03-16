#lang racket/base

;;; controllers/auth.rkt
;;; Simple name-only authentication: pick your name from the users table.
;;; No passwords yet — easy to add a bcrypt hash column later.

(require web-server/http
         web-server/http/xexpr
         "../components/db.rkt"
         "../components/session.rkt"
         "../models/user.rkt"
         "../views/auth/login.rkt")

(provide make-auth-controller)

(struct auth-controller (show-login handle-login handle-logout) #:transparent)

(define (make-auth-controller dbc session-manager)

  (define (form-field req name)
    (define b (request-bindings req))
    (define v (bindings-assq (string->bytes/utf-8 name) b))
    (and v (bytes->string/utf-8 (binding:form-value v))))

  ;; GET /login
  (define (handle-show-login req)
    (response/xexpr (login-view #f)))

  ;; POST /login
  (define (handle-login req)
    (define name (form-field req "name"))
    (define user (and name (get-user-by-name dbc name)))
    (if user
        (let ([sess (session-manager-load! session-manager req)])
          (session-set-user-id! sess (user-id user))
          (redirect-to "/"))
        (response/xexpr
         (login-view "Name not recognised. Ask a family admin to add you."))))

  ;; POST /logout
  (define (handle-logout req)
    (define sess (session-manager-load! session-manager req))
    (session-clear! sess)
    (redirect-to "/"))

  (auth-controller handle-show-login handle-login handle-logout))
