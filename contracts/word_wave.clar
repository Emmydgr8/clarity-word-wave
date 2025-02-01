;; WordWave Contract
;; Journal entries and mood tracking with achievements on Stacks

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
    entry-count: uint,
    achievements: (list 20 uint),
    streaks: {
      current: uint,
      longest: uint,
      last-entry: uint
    }
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

(define-map achievements uint
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    required-entries: uint
  }
)

;; Achievement Constants
(define-data-var achievement-definitions
  (list 5 {
    id: uint,
    name: (string-ascii 50),
    description: (string-ascii 200),
    required-entries: uint
  })
  (list
    {
      id: u1,
      name: "Getting Started",
      description: "Create your first journal entry",
      required-entries: u1
    }
    {
      id: u2, 
      name: "Dedicated Writer",
      description: "Create 10 journal entries",
      required-entries: u10
    }
    {
      id: u3,
      name: "Consistent Journaler", 
      description: "Create 50 journal entries",
      required-entries: u50
    }
    {
      id: u4,
      name: "Writing Master",
      description: "Create 100 journal entries", 
      required-entries: u100
    }
    {
      id: u5,
      name: "Writing Legend",
      description: "Create 365 journal entries",
      required-entries: u365
    }
  )
)

;; Private Functions
(define-private (check-achievements (user-data {joined-at: uint, entry-count: uint, achievements: (list 20 uint), streaks: {current: uint, longest: uint, last-entry: uint}}))
  (let (
    (entry-count (get entry-count user-data))
    (current-achievements (get achievements user-data))
  )
    (fold check-single-achievement
      (var-get achievement-definitions)
      current-achievements)
  )
)

(define-private (check-single-achievement (achievement {id: uint, name: (string-ascii 50), description: (string-ascii 200), required-entries: uint}) 
  (current-achievements (list 20 uint)))
  (if (and
    (>= entry-count (get required-entries achievement))
    (not (is-some (index-of? current-achievements (get id achievement))))
  )
    (unwrap-panic (as-max-len? (append current-achievements (get id achievement)) u20))
    current-achievements
  )
)

(define-private (update-streak (user-data {joined-at: uint, entry-count: uint, achievements: (list 20 uint), streaks: {current: uint, longest: uint, last-entry: uint}}))
  (let (
    (current-streak (get current (get streaks user-data)))
    (longest-streak (get longest (get streaks user-data)))
    (last-entry-height (get last-entry (get streaks user-data)))
    (new-current (if (is-eq (- block-height last-entry-height) u1)
      (+ current-streak u1)
      u1))
    (new-longest (if (> new-current longest-streak)
      new-current
      longest-streak))
  )
    {
      current: new-current,
      longest: new-longest,
      last-entry: block-height
    }
  )
)

;; Public Functions
(define-public (initialize-user)
  (begin
    (asserts! (is-none (map-get? users tx-sender)) (err u103))
    (ok (map-set users tx-sender {
      joined-at: block-height,
      entry-count: u0,
      achievements: (list),
      streaks: {
        current: u0,
        longest: u0,
        last-entry: u0
      }
    }))
  )
)

(define-public (create-entry (content (string-utf8 10000)) (prompt-id uint) (mood (string-ascii 20)))
  (let (
    (user-data (unwrap! (map-get? users tx-sender) (err u104)))
    (entry-count (get entry-count user-data))
    (new-entry-id (+ entry-count u1))
    (updated-streaks (update-streak user-data))
    (new-achievements (check-achievements (merge user-data {entry-count: new-entry-id})))
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
      (merge user-data {
        entry-count: new-entry-id,
        achievements: new-achievements,
        streaks: updated-streaks
      })
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

(define-read-only (get-user-statistics (user principal))
  (let ((user-data (unwrap! (map-get? users user) err-not-found)))
    (ok {
      total-entries: (get entry-count user-data),
      current-streak: (get current (get streaks user-data)),
      longest-streak: (get longest (get streaks user-data)),
      achievements: (get achievements user-data)
    })
  )
)
