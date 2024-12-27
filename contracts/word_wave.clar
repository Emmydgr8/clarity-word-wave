;; WordWave Contract
;; Journal entries and mood tracking on Stacks

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))

;; Data Variables
(define-data-var current-prompt-id uint u0)

;; Data Maps
(define-map users principal 
  {
    joined-at: uint,
    entry-count: uint
  }
)

(define-map journal-entries (tuple (user principal) (entry-id uint))
  {
    content: (string-utf8 10000),
    timestamp: uint,
    prompt-id: uint,
    mood: (string-ascii 20)
  }
)

(define-map writing-prompts uint 
  {
    prompt: (string-utf8 500),
    created-at: uint
  }
)

;; Public Functions
(define-public (initialize-user)
  (begin
    (asserts! (is-none (map-get? users tx-sender)) (err u103))
    (ok (map-set users tx-sender {
      joined-at: block-height,
      entry-count: u0
    }))
  )
)

(define-public (create-entry (content (string-utf8 10000)) (prompt-id uint) (mood (string-ascii 20)))
  (let (
    (user-data (unwrap! (map-get? users tx-sender) (err u104)))
    (entry-count (get entry-count user-data))
    (new-entry-id (+ entry-count u1))
  )
    (map-set journal-entries {user: tx-sender, entry-id: new-entry-id}
      {
        content: content,
        timestamp: block-height,
        prompt-id: prompt-id,
        mood: mood
      }
    )
    (map-set users tx-sender 
      (merge user-data {entry-count: new-entry-id})
    )
    (ok new-entry-id)
  )
)

(define-public (add-prompt (prompt (string-utf8 500)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (let ((next-id (+ (var-get current-prompt-id) u1)))
      (map-set writing-prompts next-id 
        {
          prompt: prompt,
          created-at: block-height
        }
      )
      (var-set current-prompt-id next-id)
      (ok next-id)
    )
  )
)

;; Read Only Functions
(define-read-only (get-entry (user principal) (entry-id uint))
  (map-get? journal-entries {user: user, entry-id: entry-id})
)

(define-read-only (get-prompt (prompt-id uint))
  (map-get? writing-prompts prompt-id)
)

(define-read-only (get-user-data (user principal))
  (map-get? users user)
)

(define-read-only (get-current-prompt)
  (map-get? writing-prompts (var-get current-prompt-id))
)