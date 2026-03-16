#lang racket/base

;;; main.rkt
;;; Entry point.  Assembles components, defines routing, starts the server.

(require web-server/servlet
         web-server/servlet-env
         web-server/http
         web-server/http/xexpr
         web-server/dispatch
         koyo/session
         "components/db.rkt"
         "components/session.rkt"
         "controllers/entries.rkt"
         "controllers/auth.rkt")

;; ---- Configuration ---------------------------------------------------------

(define db-path
  (or (getenv "DATABASE_PATH") "family-glossary.db"))

(define session-secret
  (or (getenv "SESSION_SECRET")
      (begin
        (displayln "WARNING: using default session secret — set SESSION_SECRET in production!")
        "dev-secret-change-me")))

(define server-port
  (string->number (or (getenv "PORT") "8080")))

;; ---- Assemble components ---------------------------------------------------

(define dbc             (make-db-component db-path))
(define session-manager (make-session-component (string->bytes/utf-8 session-secret)))
(define entries-ctrl    (make-entries-controller dbc session-manager))
(define auth-ctrl       (make-auth-controller    dbc session-manager))

;; ---- Method override -------------------------------------------------------
;;
;; HTML forms only support GET and POST.  We use a hidden _method field
;; to signal PUT (update) and DELETE, which the router checks below.

(define (method-override req)
  (if (equal? (request-method req) #"POST")
      (let* ([b (request-bindings req)]
             [v (bindings-assq #"_method" b)])
        (if v
            (string->symbol
             (string-upcase (bytes->string/utf-8 (binding:form-value v))))
            'POST))
      (string->symbol
       (string-upcase (bytes->string/utf-8 (request-method req))))))

;; ---- 404 / 405 responses ---------------------------------------------------

(define (response-404 req)
  (response/xexpr
   #:code 404
   `(html (head (title "Not Found"))
          (body (h1 "404 — Not Found")
                (p (a ([href "/"]) "Back to glossary"))))))

(define (response-405 req)
  (response/xexpr
   #:code 405
   `(html (head (title "Method Not Allowed"))
          (body (h1 "405 — Method Not Allowed")))))

;; ---- Router ----------------------------------------------------------------

(define-values (app _)
  (dispatch-rules+applies
   ;; Home
   [("")                             #:method "GET"
    (entries-controller-index entries-ctrl)]

   ;; New entry form — must come before /:id to avoid "new" being parsed as integer
   [("entries" "new")                #:method "GET"
    (entries-controller-new-form entries-ctrl)]

   ;; Create entry
   [("entries")                      #:method "POST"
    (entries-controller-create entries-ctrl)]

   ;; Show entry
   [("entries" (integer-arg))        #:method "GET"
    (lambda (req id) ((entries-controller-show entries-ctrl) req id))]

   ;; Edit form
   [("entries" (integer-arg) "edit") #:method "GET"
    (lambda (req id) ((entries-controller-edit-form entries-ctrl) req id))]

   ;; Update / delete via POST + _method override
   [("entries" (integer-arg))        #:method "POST"
    (lambda (req id)
      (case (method-override req)
        [(PUT)  ((entries-controller-update entries-ctrl) req id)]
        [else   ((entries-controller-delete entries-ctrl) req id)]))]

   ;; Explicit delete route (used by the form's action attribute)
   [("entries" (integer-arg) "delete") #:method "POST"
    (lambda (req id) ((entries-controller-delete entries-ctrl) req id))]

   ;; Auth
   [("login")  #:method "GET"  (auth-controller-show-login   auth-ctrl)]
   [("login")  #:method "POST" (auth-controller-handle-login  auth-ctrl)]
   [("logout") #:method "POST" (auth-controller-handle-logout auth-ctrl)]))

;; Wrap the dispatcher so unmatched routes get a clean 404.
(define app*
  ((wrap-session session-manager)
   (lambda (req)
     (if (app req)
         (app req)
         (response-404 req)))))

;; ---- Start server ----------------------------------------------------------

(printf "Starting Family Glossary on http://localhost:~a~n" server-port)
(serve/servlet app*
               #:port server-port
               #:launch-browser? #f
               #:servlet-path "/"
               #:servlet-regexp #rx""
               #:extra-files-paths (list (build-path (current-directory) "static")))
