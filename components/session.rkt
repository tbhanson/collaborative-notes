#lang racket/base

;;; components/session.rkt

(require koyo/session
         racket/contract)

(provide (contract-out
          [make-session-component  (-> bytes? session-manager?)]
          [session-user-id         (-> session-manager? (or/c exact-integer? #f))]
          [session-set-user-id!    (-> session-manager? exact-integer? void?)]
          [session-clear!          (-> session-manager? void?)]))

(define (make-session-component secret-bytes)
  (define store (make-memory-session-store #:ttl (* 30 24 60 60)))
  (define factory
    (make-session-manager-factory
     #:cookie-name  "fg_sess"
     #:shelf-life   (* 30 24 60 60)
     #:secret-key   secret-bytes
     #:store        store
     #:cookie-secure? #f))
  (factory))

(define (session-user-id sm)
  (define v (session-manager-ref sm 'user-id #f))
  (and v (string->number v)))

(define (session-set-user-id! sm uid)
  (session-manager-set! sm 'user-id (number->string uid))
  (void))

(define (session-clear! sm)
  (session-manager-remove! sm 'user-id)
  (void))
