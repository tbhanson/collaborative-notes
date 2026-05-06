#lang racket/base

;;; controllers/entries.rkt
;;; HTTP handlers for listing, viewing, creating, editing, and deleting entries.

(require racket/contract
         racket/match
         racket/string
         net/url
         web-server/http
         web-server/http/bindings
         web-server/http/xexpr
         "../components/db.rkt"
         "../components/session.rkt"
         "../models/entry.rkt"
         "../models/change.rkt"
         "../models/user.rkt"
         "../views/entries/index.rkt"
         "../views/entries/show.rkt"
         "../views/entries/form.rkt")

(provide make-entries-controller
         entries-controller-index
         entries-controller-show
         entries-controller-new-form
         entries-controller-create
         entries-controller-edit-form
         entries-controller-update
         entries-controller-delete)

(struct entries-controller
  (index show new-form create edit-form update delete)
  #:transparent)

(define (make-entries-controller dbc session-manager)

  (define (current-user req)
    (define uid (session-user-id session-manager))
    (and uid (get-user-by-id dbc uid)))

  ;; Require login — redirect to /login if not authenticated.
  (define (with-login req handler)
    (define me (current-user req))
    (if me
        (handler me)
        (redirect-to "/login")))

  ;; Require editor role — return 403 if viewer.
  (define (with-editor req handler)
    (with-login req
      (lambda (me)
        (if (user-editor? me)
            (handler me)
            (response/xexpr
             #:code 403
             `(html (head (title "Forbidden"))
                    (body (h1 "403 — Forbidden")
                          (p "You don't have permission to do that.")
                          (p (a ([href "/"]) "Back to glossary")))))))))

  (define (form-field req name)
    (define bindings (request-bindings req))
    (define pair (assq (string->symbol name) bindings))
    (and pair (cdr pair)))

  (define (parse-sort req)
    (define pairs (url-query (request-uri req)))
    (define p (assoc "sort" pairs))
    (if (and p (equal? (cdr p) "date")) 'date 'alpha))

  ;; ---- GET / ---------------------------------------------------------------
  (define (handle-index req)
    (with-login req
      (lambda (me)
        (define sort-param (parse-sort req))
        (define entries (list-entries dbc #:sort sort-param #:include-deleted? #f))
        (define users (list-users dbc))
        (define user-names
          (for/hash ([u users])
            (values (user-id u) (user-display u))))
        (response/xexpr
         (entries-index-view entries sort-param user-names
                             (user-display me)
                             (user-editor? me))))))

  ;; ---- GET /entries/:id ----------------------------------------------------
  (define (handle-show req id)
    (with-login req
      (lambda (me)
        (define e (get-entry dbc id))
        (if (not e)
            (response-404)
            (let* ([creator (get-user-by-id dbc (entry-created-by e))]
                   [changes (list-changes-for-entry dbc id)])
              (response/xexpr
               (entry-show-view e
                                (if creator (user-display creator) "unknown")
                                changes
                                (user-display me)
                                (user-editor? me))))))))

  ;; ---- GET /entries/new ----------------------------------------------------
  (define (handle-new req)
    (with-editor req
      (lambda (me)
        (response/xexpr (entry-form-view #f #f (user-display me))))))

  ;; ---- POST /entries -------------------------------------------------------
  (define (handle-create req)
    (with-editor req
      (lambda (me)
        (define title    (form-field req "title"))
        (define phonetic (form-field req "phonetic"))
        (define body     (form-field req "body"))
        (if (or (not title) (string=? (string-trim title) ""))
            (response/xexpr
             (entry-form-view #f "Title is required." (user-display me)))
            (let ([new-id (create-entry! dbc
                                         #:title    (string-trim title)
                                         #:body     (non-empty body)
                                         #:phonetic (non-empty phonetic)
                                         #:user-id  (user-id me))])
              (redirect-to (string-append "/entries/" (number->string new-id))))))))

  ;; ---- GET /entries/:id/edit -----------------------------------------------
  (define (handle-edit req id)
    (with-editor req
      (lambda (me)
        (define e (get-entry dbc id))
        (if (not e)
            (response-404)
            (response/xexpr (entry-form-view e #f (user-display me)))))))

  ;; ---- POST /entries/:id ---------------------------------------------------
  (define (handle-update req id)
    (with-editor req
      (lambda (me)
        (define title    (form-field req "title"))
        (define phonetic (form-field req "phonetic"))
        (define body     (form-field req "body"))
        (if (or (not title) (string=? (string-trim title) ""))
            (let ([e (get-entry dbc id)])
              (response/xexpr
               (entry-form-view e "Title is required." (user-display me))))
            (begin
              (update-entry! dbc
                             #:id       id
                             #:title    (string-trim title)
                             #:body     (non-empty body)
                             #:phonetic (non-empty phonetic)
                             #:user-id  (user-id me))
              (redirect-to (string-append "/entries/" (number->string id))))))))

  ;; ---- POST /entries/:id/delete --------------------------------------------
  (define (handle-delete req id)
    (with-editor req
      (lambda (me)
        (delete-entry! dbc #:id id #:user-id (user-id me))
        (redirect-to "/"))))

  (entries-controller handle-index
                      handle-show
                      handle-new
                      handle-create
                      handle-edit
                      handle-update
                      handle-delete))

;; ---- Helpers ---------------------------------------------------------------

(define (non-empty s)
  (and s
       (let ([t (string-trim s)])
         (and (not (string=? t "")) t))))

(define (response-404)
  (response/xexpr
   #:code 404
   `(html (head (title "Not Found"))
          (body (h1 "404 Not Found")
                (p (a ([href "/"]) "Back to glossary"))))))
