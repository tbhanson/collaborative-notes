#lang racket/base

;;; controllers/account.rkt
;;; Handles account management — currently just password changes.

(require web-server/http
         web-server/http/bindings
         web-server/http/xexpr
         "../components/db.rkt"
         "../components/session.rkt"
         "../models/user.rkt"
         "../views/auth/change-password.rkt")

(provide make-account-controller
         account-controller-show-change-password
         account-controller-handle-change-password)

(struct account-controller
  (show-change-password handle-change-password)
  #:transparent)

(define (make-account-controller dbc session-manager)

  (define (current-user req)
    (define uid (session-user-id session-manager))
    (and uid (get-user-by-id dbc uid)))

  (define (form-field req name)
    (define bindings (request-bindings req))
    (define pair (assq (string->symbol name) bindings))
    (and pair (cdr pair)))

  (define (require-login req handler)
    (define me (current-user req))
    (if me (handler me) (redirect-to "/login")))

  ;; GET /account/password
  (define (handle-show-change-password req)
    (require-login req
      (lambda (me)
        (response/xexpr
         (change-password-view #f #f (user-display me))))))

  ;; POST /account/password
  (define (handle-change-password req)
    (require-login req
      (lambda (me)
        (define current-pw  (form-field req "current-password"))
        (define new-pw      (form-field req "new-password"))
        (define confirm-pw  (form-field req "confirm-password"))
        (define result
          (change-password! dbc (user-id me)
                            (or current-pw "")
                            (or new-pw "")
                            (or confirm-pw "")))
        (case result
          [(ok)
           (response/xexpr
            (change-password-view #f "Password changed successfully." (user-display me)))]
          [(wrong-password)
           (response/xexpr
            (change-password-view "Current password is incorrect." #f (user-display me)))]
          [(mismatch)
           (response/xexpr
            (change-password-view "New passwords do not match." #f (user-display me)))]))))

  (account-controller handle-show-change-password
                      handle-change-password))
