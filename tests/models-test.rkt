#lang racket/base

;;; tests/models-test.rkt
;;; Unit tests for the models layer using an in-memory SQLite database.
;;; Run with:  raco test tests/models-test.rkt

(require rackunit
         db
         "../components/db.rkt"
         "../models/user.rkt"
         "../models/entry.rkt"
         "../models/change.rkt")

;; ---- Test fixture ----------------------------------------------------------

;; Creates a fresh in-memory DB with migrations applied.
(define (make-test-db)
  (make-db-component 'memory))   ; SQLite ':memory:' via symbol

;; ---- User tests ------------------------------------------------------------

(define user-tests
  (test-suite
   "User model"

   (test-case "look up seeded user by name"
              (define dbc (make-test-db))
              (define u (get-user-by-name dbc "tim"))
              (check-not-false u)
              (check-equal? (user-name u) "tim")
              (check-equal? (user-display u) "Tim"))

   (test-case "missing user returns #f"
              (define dbc (make-test-db))
              (check-false (get-user-by-name dbc "nobody")))

   (test-case "list-users returns all seeded users"
              (define dbc (make-test-db))
              (define users (list-users dbc))
              (check-true (>= (length users) 1)))))

;; ---- Entry tests -----------------------------------------------------------

(define entry-tests
  (test-suite
   "Entry model"

   (test-case "create and retrieve an entry"
              (define dbc (make-test-db))
              (define uid (user-id (get-user-by-name dbc "tim")))
              (define new-id (create-entry! dbc
                                            #:title    "Schnabulieren"
                                            #:body     "To snack enthusiastically"
                                            #:phonetic "ʃnabuˈliːʁən"
                                            #:user-id  uid))
              (define e (get-entry dbc new-id))
              (check-not-false e)
              (check-equal? (entry-title e) "Schnabulieren")
              (check-equal? (entry-phonetic e) "ʃnabuˈliːʁən"))

   (test-case "create records audit trail"
              (define dbc (make-test-db))
              (define uid (user-id (get-user-by-name dbc "tim")))
              (define new-id (create-entry! dbc #:title "Foo" #:body #f #:phonetic #f #:user-id uid))
              (define changes (list-changes-for-entry dbc new-id))
              (check-true (>= (length changes) 1))
              (check-equal? (change-field (car changes)) "title"))

   (test-case "update records only changed fields"
              (define dbc (make-test-db))
              (define uid (user-id (get-user-by-name dbc "tim")))
              (define eid (create-entry! dbc #:title "Bar" #:body "original" #:phonetic #f #:user-id uid))
              (update-entry! dbc #:id eid #:title "Bar" #:body "updated" #:phonetic #f #:user-id uid)
              (define changes (list-changes-for-entry dbc eid))
              ;; Should have initial 'title' create change, plus one 'body' update change.
              (define fields (map change-field changes))
;              (check-true (member "body" fields) "body change should be recorded") ; subtle test bug!
              (check-not-false (member "body" fields) "body change should be recorded")

              ;; Title did not change, so no second title entry.
              (check-equal? (length (filter (lambda (c) (equal? (change-field c) "title")) changes)) 1))

   (test-case "soft delete removes from list but not from DB"
              (define dbc (make-test-db))
              (define uid (user-id (get-user-by-name dbc "tim")))
              (define eid (create-entry! dbc #:title "TempWord" #:body #f #:phonetic #f #:user-id uid))
              (delete-entry! dbc #:id eid #:user-id uid)
              (define active (list-entries dbc #:sort 'alpha #:include-deleted? #f))
              (define all    (list-entries dbc #:sort 'alpha #:include-deleted? #t))
              (check-false (findf (lambda (e) (= (entry-id e) eid)) active))
              (check-not-false (findf (lambda (e) (= (entry-id e) eid)) all)))

   (test-case "list-entries alpha sort"
              (define dbc (make-test-db))
              (define uid (user-id (get-user-by-name dbc "tim")))
              (create-entry! dbc #:title "Zebra" #:body #f #:phonetic #f #:user-id uid)
              (create-entry! dbc #:title "Apple" #:body #f #:phonetic #f #:user-id uid)
              (define entries (list-entries dbc #:sort 'alpha #:include-deleted? #f))
              (define titles  (map entry-title entries))
              (check-equal? titles (sort titles string-ci<?)))))

;; ---- Run all ---------------------------------------------------------------

(run-test user-tests)
(run-test entry-tests)
