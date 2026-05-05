#lang racket/base

;;; views/auth/change-password.rkt

(require racket/contract
         "../layout.rkt")

(provide (contract-out
          [change-password-view (-> (or/c string? #f)
                                    (or/c string? #f)
                                    (or/c string? #f)
                                    list?)]))

;; error-msg   — validation error to display, or #f
;; success-msg — confirmation message, or #f
;; current-user — display name for nav
(define (change-password-view error-msg success-msg current-user)
  (layout
   "Change Password"
   current-user
   `(,@(if error-msg
           `((div ([class "alert alert-error"]) ,error-msg))
           '())
     ,@(if success-msg
           `((div ([class "alert alert-success"]) ,success-msg))
           '())
     (div ([class "login-box"])
       (h1 "Change Password")
       (form ([method "post"] [action "/account/password"])
         (div ([class "form-group"])
           (label ([for "current-password"]) "Current password")
           (input ([type "password"] [id "current-password"]
                   [name "current-password"] [required "required"]
                   [autocomplete "current-password"])))
         (div ([class "form-group"])
           (label ([for "new-password"]) "New password")
           (input ([type "password"] [id "new-password"]
                   [name "new-password"] [required "required"]
                   [autocomplete "new-password"])))
         (div ([class "form-group"])
           (label ([for "confirm-password"]) "Confirm new password")
           (input ([type "password"] [id "confirm-password"]
                   [name "confirm-password"] [required "required"]
                   [autocomplete "new-password"])))
         (div ([class "form-actions"])
           (button ([type "submit"] [class "btn btn-primary"]) "Change Password")
           " "
           (a ([href "/"]) "Cancel")))))))
