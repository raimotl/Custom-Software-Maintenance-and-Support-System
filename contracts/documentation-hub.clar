;; Documentation Hub Contract
;; Manages technical documentation and user training materials

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-DOC-NOT-FOUND (err u501))
(define-constant ERR-TRAINING-NOT-FOUND (err u502))
(define-constant ERR-ALREADY-COMPLETED (err u503))

;; Data Variables
(define-data-var next-doc-id uint u1)
(define-data-var next-training-id uint u1)

;; Data Maps
(define-map documents
  { doc-id: uint }
  {
    title: (string-ascii 200),
    content-hash: (string-ascii 64),
    version: (string-ascii 20),
    category: (string-ascii 50),
    author: principal,
    created-at: uint,
    updated-at: uint,
    public: bool
  }
)

(define-map training-materials
  { training-id: uint }
  {
    title: (string-ascii 200),
    description: (string-ascii 500),
    content-hash: (string-ascii 64),
    duration-minutes: uint,
    difficulty: (string-ascii 20),
    created-by: principal,
    created-at: uint
  }
)

(define-map user-training-progress
  { user: principal, training-id: uint }
  {
    started-at: uint,
    completed-at: (optional uint),
    progress-percentage: uint,
    score: (optional uint)
  }
)

(define-map document-permissions
  { user: principal }
  { can-create: bool, can-edit: bool, can-delete: bool }
)

;; Private Functions
(define-private (is-authorized-doc (user principal))
  (or
    (is-eq user CONTRACT-OWNER)
    (default-to false (get can-create (map-get? document-permissions { user: user })))
  )
)

(define-private (can-edit-doc (user principal))
  (or
    (is-eq user CONTRACT-OWNER)
    (default-to false (get can-edit (map-get? document-permissions { user: user })))
  )
)

(define-private (is-valid-difficulty (difficulty (string-ascii 20)))
  (or
    (is-eq difficulty "beginner")
    (is-eq difficulty "intermediate")
    (is-eq difficulty "advanced")
  )
)

;; Public Functions
(define-public (set-doc-permissions (user principal) (can-create bool) (can-edit bool) (can-delete bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set document-permissions
      { user: user }
      { can-create: can-create, can-edit: can-edit, can-delete: can-delete }
    ))
  )
)

(define-public (create-document (title (string-ascii 200)) (content-hash (string-ascii 64)) (version (string-ascii 20)) (category (string-ascii 50)) (public bool))
  (let ((doc-id (var-get next-doc-id)))
    (asserts! (is-authorized-doc tx-sender) ERR-NOT-AUTHORIZED)
    (map-set documents
      { doc-id: doc-id }
      {
        title: title,
        content-hash: content-hash,
        version: version,
        category: category,
        author: tx-sender,
        created-at: block-height,
        updated-at: block-height,
        public: public
      }
    )
    (var-set next-doc-id (+ doc-id u1))
    (ok doc-id)
  )
)

(define-public (update-document (doc-id uint) (title (string-ascii 200)) (content-hash (string-ascii 64)) (version (string-ascii 20)))
  (let ((doc-data (unwrap! (map-get? documents { doc-id: doc-id }) ERR-DOC-NOT-FOUND)))
    (asserts! (can-edit-doc tx-sender) ERR-NOT-AUTHORIZED)
    (ok (map-set documents
      { doc-id: doc-id }
      (merge doc-data {
        title: title,
        content-hash: content-hash,
        version: version,
        updated-at: block-height
      })
    ))
  )
)

(define-public (create-training (title (string-ascii 200)) (description (string-ascii 500)) (content-hash (string-ascii 64)) (duration uint) (difficulty (string-ascii 20)))
  (let ((training-id (var-get next-training-id)))
    (asserts! (is-authorized-doc tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-difficulty difficulty) ERR-NOT-AUTHORIZED)
    (map-set training-materials
      { training-id: training-id }
      {
        title: title,
        description: description,
        content-hash: content-hash,
        duration-minutes: duration,
        difficulty: difficulty,
        created-by: tx-sender,
        created-at: block-height
      }
    )
    (var-set next-training-id (+ training-id u1))
    (ok training-id)
  )
)

(define-public (start-training (training-id uint))
  (begin
    (asserts! (is-some (map-get? training-materials { training-id: training-id })) ERR-TRAINING-NOT-FOUND)
    (ok (map-set user-training-progress
      { user: tx-sender, training-id: training-id }
      {
        started-at: block-height,
        completed-at: none,
        progress-percentage: u0,
        score: none
      }
    ))
  )
)

(define-public (complete-training (training-id uint) (score uint))
  (let ((progress-data (unwrap! (map-get? user-training-progress { user: tx-sender, training-id: training-id }) ERR-TRAINING-NOT-FOUND)))
    (asserts! (is-none (get completed-at progress-data)) ERR-ALREADY-COMPLETED)
    (asserts! (<= score u100) ERR-NOT-AUTHORIZED)
    (ok (map-set user-training-progress
      { user: tx-sender, training-id: training-id }
      (merge progress-data {
        completed-at: (some block-height),
        progress-percentage: u100,
        score: (some score)
      })
    ))
  )
)

;; Read-only Functions
(define-read-only (get-document (doc-id uint))
  (map-get? documents { doc-id: doc-id })
)

(define-read-only (get-training-material (training-id uint))
  (map-get? training-materials { training-id: training-id })
)

(define-read-only (get-user-training-progress (user principal) (training-id uint))
  (map-get? user-training-progress { user: user, training-id: training-id })
)

(define-read-only (get-next-doc-id)
  (var-get next-doc-id)
)

(define-read-only (get-next-training-id)
  (var-get next-training-id)
)

(define-read-only (get-user-doc-permissions (user principal))
  (map-get? document-permissions { user: user })
)
