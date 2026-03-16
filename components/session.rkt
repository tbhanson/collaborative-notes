#lang racket/base

;;; components/session.rkt
;;; Wraps Koyo's session manager.  Stores the logged-in user's id
;;; as a string in a signed cookie session.
;;;
;;; Key Koyo session API used here:
;;;   make-session-manager  — creates the manager component
;;;   session-manager-load! — loads (or creates) a session for a request
;;;   session-ref           — read a value from the session hash
;;;   session-set!          — write a value into the session hash
;;;   session-remove!       — delete a key from the session hash
;;;
;;; Koyo automatically sets the Set-Cookie header when the response is
;;; sent, as long as the session manager wraps the servlet.

(require koyo/session
         racket/contract)

(provide (contract-out
          [make-session-component  (-> bytes? session-manager?)]
          [session-user-id         (-> session? (or/c exact-integer? #f))]
          [session-set-user-id!    (-> session? exact-integer? void?)]
          [session-clear!          (-> session? void?)]))

;; The secret is used to sign the session cookie.
;; In production, supply via SESSION_SECRET environment variable.
(define (make-session-component secret-bytes)
  (make-session-manager
   #:cookie-name "fg_sess"
   #:secret-key  secret-bytes
   #:store       (make-memory-session-store
                  #:ttl (* 30 24 60 60))))  ; 30-day TTL

(define (session-user-id sess)
  (define v (session-ref sess 'user-id #f))
  (and v (string->number v)))

(define (session-set-user-id! sess uid)
  (session-set! sess 'user-id (number->string uid))
  (void))

(define (session-clear! sess)
  (session-remove! sess 'user-id)
  (void))
