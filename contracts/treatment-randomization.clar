;; Treatment Randomization Contract
;; Assigns patients to treatment groups

(define-data-var admin principal tx-sender)

;; Treatment groups
(define-map treatment-groups
  { group-id: (string-ascii 10) }
  {
    name: (string-ascii 50),
    description: (string-ascii 255),
    max-patients: uint,
    current-count: uint
  }
)

;; Patient assignments
(define-map patient-assignments
  { patient-id: (string-ascii 20) }
  { group-id: (string-ascii 10) }
)

;; Random seed for randomization
(define-data-var random-seed uint u0)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Create a new treatment group
(define-public (create-treatment-group
    (group-id (string-ascii 10))
    (name (string-ascii 50))
    (description (string-ascii 255))
    (max-patients uint))
  (begin
    (asserts! (is-admin) (err u403))
    (asserts! (is-none (map-get? treatment-groups { group-id: group-id })) (err u409)) ;; Group ID must be unique

    (map-set treatment-groups
      { group-id: group-id }
      {
        name: name,
        description: description,
        max-patients: max-patients,
        current-count: u0
      }
    )
    (ok true)
  )
)

;; Get treatment group info
(define-read-only (get-treatment-group (group-id (string-ascii 10)))
  (map-get? treatment-groups { group-id: group-id })
)

;; Get patient assignment
(define-read-only (get-patient-assignment (patient-id (string-ascii 20)))
  (map-get? patient-assignments { patient-id: patient-id })
)

;; Simple pseudo-random number generator
(define-private (generate-random-number (max uint))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (new-seed (+ (var-get random-seed) current-time))
    )
    (begin
      (var-set random-seed new-seed)
      (mod new-seed max)
    )
  )
)

;; Assign a patient to a treatment group
(define-public (randomize-patient (patient-id (string-ascii 20)) (available-groups (list 10 (string-ascii 10))))
  (let
    (
      (group-count (len available-groups))
      (random-index (generate-random-number group-count))
      (selected-group (unwrap-panic (element-at available-groups random-index)))
      (group-data (unwrap! (map-get? treatment-groups { group-id: selected-group }) (err u404)))
    )

    (asserts! (is-admin) (err u403))
    (asserts! (> group-count u0) (err u400)) ;; Must have at least one group
    (asserts! (is-none (map-get? patient-assignments { patient-id: patient-id })) (err u409)) ;; Patient must not be already assigned
    (asserts! (< (get current-count group-data) (get max-patients group-data)) (err u507)) ;; Group must not be full

    ;; Update group count
    (map-set treatment-groups
      { group-id: selected-group }
      (merge group-data
             { current-count: (+ (get current-count group-data) u1) })
    )

    ;; Assign patient to group
    (map-set patient-assignments
      { patient-id: patient-id }
      { group-id: selected-group }
    )

    (ok selected-group)
  )
)

;; Manually assign a patient to a specific group (for special cases)
(define-public (assign-patient (patient-id (string-ascii 20)) (group-id (string-ascii 10)))
  (let
    ((group-data (unwrap! (map-get? treatment-groups { group-id: group-id }) (err u404))))

    (asserts! (is-admin) (err u403))
    (asserts! (is-none (map-get? patient-assignments { patient-id: patient-id })) (err u409)) ;; Patient must not be already assigned
    (asserts! (< (get current-count group-data) (get max-patients group-data)) (err u507)) ;; Group must not be full

    ;; Update group count
    (map-set treatment-groups
      { group-id: group-id }
      (merge group-data
             { current-count: (+ (get current-count group-data) u1) })
    )

    ;; Assign patient to group
    (map-set patient-assignments
      { patient-id: patient-id }
      { group-id: group-id }
    )

    (ok true)
  )
)

;; Change admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)

