#lang racket/base

;;; views/auth/login.rkt

(require racket/contract
         "../layout.rkt")

(provide (contract-out
          [login-view (-> (or/c string? #f) list?)]))

(define (login-view error-msg)
  (layout
   "Log In"
   #f
   `(,@(if error-msg
           `((div ([class "alert alert-error"]) ,error-msg))
           '())
     (div ([class "login-box"])
       (h1 "Log In")
       (form ([method "post"] [action "/login"])
         (div ([class "form-group"])
           (label ([for "name"]) "Your name")
           (input ([type "text"] [id "name"] [name "name"]
                   [placeholder "e.g. tim"] [required "required"])))
         (div ([class "form-actions"])
           (button ([type "submit"] [class "btn btn-primary"]) "Log In")))))))
