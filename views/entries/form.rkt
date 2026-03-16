#lang racket/base

;;; views/entries/form.rkt
;;; Shared form for both creating and editing entries.

(require racket/contract
         "../../models/entry.rkt"
         "../layout.rkt")

(provide (contract-out
          [entry-form-view
           (-> (or/c entry? #f)         ; #f for new, entry for edit
               (or/c string? #f)        ; error message
               (or/c string? #f)        ; current user display name
               list?)]))

(define (entry-form-view maybe-entry error-msg current-user)
  (define editing? (and maybe-entry #t))
  (define id-str   (and editing? (number->string (entry-id maybe-entry))))
  (define action   (if editing?
                       (string-append "/entries/" id-str)
                       "/entries"))
  (define page-title (if editing? "Edit Entry" "New Entry"))

  (layout
   page-title
   current-user
   `(,@(if error-msg
           `((div ([class "alert alert-error"]) ,error-msg))
           '())
     (h1 ,page-title)
     (form ([method "post"] [action ,action] [class "entry-form"])
       ;; Override method for edit (HTML forms only support GET/POST)
       ,@(if editing? '((input ([type "hidden"] [name "_method"] [value "PUT"]))) '())

       (div ([class "form-group"])
         (label ([for "title"]) "Title (word or syllable)")
         (input ([type "text"]
                 [id "title"]
                 [name "title"]
                 [required "required"]
                 [value ,(if editing? (entry-title maybe-entry) "")])))

       (div ([class "form-group"])
         (label ([for "phonetic"]) "Phonetic spelling (optional)")
         (input ([type "text"]
                 [id "phonetic"]
                 [name "phonetic"]
                 [value ,(if (and editing? (entry-phonetic maybe-entry))
                             (entry-phonetic maybe-entry)
                             "")])))

       (div ([class "form-group"])
         (label ([for "body"]) "Definition / notes (optional)")
         (textarea ([id "body"] [name "body"] [rows "5"])
                   ,(if (and editing? (entry-body maybe-entry))
                        (entry-body maybe-entry)
                        "")))

       (div ([class "form-actions"])
         (button ([type "submit"] [class "btn btn-primary"])
                 ,(if editing? "Save Changes" "Create Entry"))
         " "
         (a ([href ,(if editing? (string-append "/entries/" id-str) "/")])
            "Cancel"))))))
