#lang racket/base

;;; controllers/auth.rkt
;;; Login/logout handlers with password verification.

(require web-server/http
         web-server/http/bindings
         web-server/http/xexpr
         "../components/db.rkt"
         "../components/session.rkt"
         "../models/user.rkt"
         "../views/auth/login.rkt")

(provide make-auth-controller
         auth-controller-show-login
         auth-controller-handle-login
         auth-controller-handle-logout)

(struct auth-controller (show-login handle-login handle-logout) #:transparent)

(define (make-auth-controller dbc session-manager)

  (define (form-field req name)
    (define bindings (request-bindings req))
    (define pair (assq (string->symbol name) bindings))
    (and pair (cdr pair)))

  ;; GET /login
  (define (handle-show-login req)
    (response/xexpr (login-view #f)))

  ;; POST /login — verify name + password
  (define (handle-login req)
    (define name     (form-field req "name"))
    (define password (form-field req "password"))
    (define user
      (and name password
           (check-password dbc name password)))
    (if user
        (begin
          (session-set-user-id! session-manager (user-id user))
          (redirect-to "/"))
        (begin
          (sleep 2)
          (response/xexpr
           (login-view "Invalid name or password.")))))

  ;; POST /logout
  (define (handle-logout req)
    (session-clear! session-manager)
    (redirect-to "/"))

  (auth-controller handle-show-login handle-login handle-logout))
