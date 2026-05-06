#lang racket/base

;;; views/entries/show.rkt
;;; Single entry page with its full audit trail.

(require racket/contract
         racket/list
         racket/string
         "../../models/entry.rkt"
         "../../models/change.rkt"
         "../layout.rkt")

(provide (contract-out
          [entry-show-view
           (-> entry?
               string?                  ; creator display name
               (listof change?)
               (or/c string? #f)        ; current user display name
               boolean?                 ; is current user an editor?
               list?)]))

(define (entry-show-view e creator-name changes current-user editor?)
  (layout
   (entry-title e)
   current-user
   `((article ([class "entry-detail"])
       (header
        (h1 ,(entry-title e))
        ,@(if (entry-phonetic e)
              `((p ([class "phonetic"]) "[" ,(entry-phonetic e) "]"))
              '()))
       ,@(if (entry-body e)
             `((section ([class "entry-body"])
                 (p ,(entry-body e))))
             '())
       (footer ([class "entry-meta"])
         (span "Added by " ,creator-name " on " ,(substring (entry-created-at e) 0 10))
         ,@(if editor?
               `((span " · "
                   (a ([href ,(string-append "/entries/"
                                             (number->string (entry-id e))
                                             "/edit")])
                      "Edit")
                   " · "
                   (form ([method "post"]
                          [action ,(string-append "/entries/"
                                                  (number->string (entry-id e))
                                                  "/delete")]
                          [class "inline-form"])
                     (button ([type "submit"]
                              [class "btn-danger"]
                              [onclick "return confirm('Delete this entry?')"])
                             "Delete"))))
               '())))
     ,(change-history-section changes))))

(define (change-history-section changes)
  (if (null? changes)
      '(p "No change history.")
      `(section ([class "change-history"])
         (h2 "Change History")
         (table
          (thead
           (tr (th "When") (th "Who") (th "Field") (th "Before") (th "After")))
          (tbody
           ,@(map change-row changes))))))

(define (change-row c)
  `(tr
    (td ,(substring (change-changed-at c) 0 10))
    (td ,(change-display-name c))
    (td ,(change-field c))
    (td ([class "old-value"]) ,(or (change-old-value c) "—"))
    (td ([class "new-value"]) ,(or (change-new-value c) "—"))))
