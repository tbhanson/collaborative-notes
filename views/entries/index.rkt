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
               (or/c string? #f)        ; logged-in display name
               list?)]))                ; xexpr

(define (entries-index-view entries sort-by current-user)
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
       ,@(if current-user
             `((a ([href "/entries/new"] [class "btn btn-primary"]) "+ New Entry"))
             '()))
     ,(if (null? entries)
          `(p ([class "empty"]) "No entries yet.")
          `(table ([class "entries-table"])
             (thead
              (tr (th "Title") (th "Phonetic") (th "Added by") (th "Date") (th "")))
             (tbody
              ,@(map entry-row entries)))))))

(define (sort-link label key current)
  (define active? (string=? key (symbol->string current)))
  `(a ([href ,(string-append "/?sort=" key)]
       [class ,(if active? "sort-link active" "sort-link")])
     ,label))

(define (entry-row e)
  `(tr
    (td (a ([href ,(string-append "/entries/" (number->string (entry-id e)))]) 
            ,(entry-title e)))
    (td ,(or (entry-phonetic e) ""))
    (td ,(number->string (entry-created-by e)))   ; replaced with display name in controller
    (td ,(entry-created-at e))
    (td (a ([href ,(string-append "/entries/" (number->string (entry-id e)) "/edit")])
            "edit"))))
