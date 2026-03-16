#lang racket/base

;;; controllers/auth.rkt
;;; Login/logout handlers.
;;;
;;; Session access works like this:
;;;   - wrap-session middleware (applied in main.rkt) runs before every
;;;     request and sets current-session-id as a parameter
;;;   - session-set-user-id! and session-clear! in components/session.rkt
;;;     call session-manager-set!/remove! which use current-session-id
;;;     internally — so we just pass the session-manager and the value,
;;;     no need to "load" the session manually

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

  ;; Extract a named field from a POST form body.
  (define (form-field req name)
    (define b (request-bindings req))
    (define v (bindings-assq (string->bytes/utf-8 name) b))
    (and v (bytes->string/utf-8 (binding:form-value v))))

  ;; GET /login — just show the form
  (define (handle-show-login req)
    (response/xexpr (login-view #f)))

  ;; POST /login — look up the name, set session if found
  (define (handle-login req)
    (define name (form-field req "name"))
    (define user (and name (get-user-by-name dbc name)))
    (if user
        (begin
          ;; Store the user's id in the session.
          ;; wrap-session has already set current-session-id for this
          ;; request, so session-set-user-id! knows which session to write.
          (session-set-user-id! session-manager (user-id user))
          (redirect-to "/"))
        (response/xexpr
         (login-view "Name not recognised. Ask a family admin to add you."))))

  ;; POST /logout — clear the user id from the session
  (define (handle-logout req)
    (session-clear! session-manager)
    (redirect-to "/"))

  (auth-controller handle-show-login handle-login handle-logout))