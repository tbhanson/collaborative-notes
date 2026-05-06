#lang racket/base

;;; views/entries/index.rkt
;;; The main list of glossary entries, with sort controls.

(require racket/contract
         racket/list
         racket/string
         "../../models/entry.rkt"
         "../layout.rkt")

(provide (contract-out
          [entries-index-view
           (-> (listof entry?)          ; entries to display
               (or/c 'alpha 'date)      ; current sort
               hash?                    ; user-id -> display-name
               (or/c string? #f)        ; logged-in display name
               boolean?                 ; is current user an editor?
               list?)]))                ; xexpr

(define (entries-index-view entries sort-by user-names current-user editor?)
  (layout
   "Entries"
   current-user
   `((section ([class "entries-header"])
              (h1 "Glossary")
              (div ([class "controls"])
                   (span "Sort: ")
                   ,(sort-link "Alphabetical" "alpha" sort-by)
                   " · "
                   ,(sort-link "By date" "date" sort-by))
              ,@(if (and current-user editor?)
                    `((a ([href "/entries/new"] [class "btn btn-primary"]) "+ New Entry"))
                    '()))
     ,(if (null? entries)
          `(p ([class "empty"]) "No entries yet.")

          `(table ([class "entries-table"])
                  (thead
                   (tr (th "Title") (th "Phonetic") (th "Definition")
                       ,@(if editor? '((th "")) '())))
                  (tbody
                   ,@(map (lambda (e) (entry-row user-names editor? e)) entries)))
          ))))

(define (sort-link label key current)
  (define active? (string=? key (symbol->string current)))
  `(a ([href ,(string-append "/?sort=" key)]
       [class ,(if active? "sort-link active" "sort-link")])
      ,label))

(define (entry-row user-names editor? e)
  `(tr
    (td (a ([href ,(string-append "/entries/" (number->string (entry-id e)))]) 
            ,(entry-title e)))
    (td ,(or (entry-phonetic e) ""))
    (td ,(or (entry-body e) ""))
    ,@(if editor?
          `((td (a ([href ,(string-append "/entries/" (number->string (entry-id e)) "/edit")])
                   "edit")))
          '())))
