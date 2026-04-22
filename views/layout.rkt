#lang racket/base

;;; views/layout.rkt
;;; Produces the outer HTML shell (doctype, nav, head) as an xexpr.
;;; All page views call (layout title body-xexprs) and return the result.

(require racket/contract
         racket/list
         web-server/http)

(provide (contract-out
          [layout (-> string?           ; page title
                      (or/c string? #f) ; logged-in display name, #f if none
                      list?             ; body xexprs
                      list?)]))         ; complete xexpr for the page

(define (layout title current-user-name body-xexprs)
  `(html
    (head
     (meta ([charset "utf-8"]))
     (meta ([name "viewport"] [content "width=device-width, initial-scale=1"]))
     (title ,title " — Family Glossary")
     (link ([rel "stylesheet"] [href "/static/style.css"])))
    (body
     (header
      (nav
       (a ([href "/"]) (strong "Family Glossary"))
       (span ([class "nav-links"])
             (a ([href "/"]) "Entries")
             ,@(if current-user-name
                   `((span ([class "user-name"]) "👤 " ,current-user-name)
                     (form ([method "post"] [action "/logout"] [class "inline-form"])
                           (button ([type "submit"] [class "btn-link"]) "Log out")))
                   `((a ([href "/login"]) "Log in"))))))
     (main
      ,@body-xexprs)
     (footer
      (p "Family Glossary")))))

