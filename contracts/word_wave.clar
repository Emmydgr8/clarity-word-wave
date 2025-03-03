;; WordWave Contract
;; Journal entries and mood tracking with achievements on Stacks

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-content (err u103))
(define-constant err-invalid-mood (err u104))
(define-constant err-user-exists (err u105))
(define-constant err-user-not-found (err u106))
(define-constant max-streak-gap u144) ;; ~24 hours in blocks

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

;; Private Functions
(define-private (check-achievements (user-data {joined-at: uint, entry-count: uint, achievements: (list 20 uint), streaks: {current: uint, longest: uint, last-entry: uint}}))
  (let (
    (entry-count (get entry-count user-data))
    (current-achievements (get achievements user-data))
  )
    (fold check-single-achievement-with-count
      (map wrap-with-entry-count (var-get achievement-definitions))
      current-achievements)
  )
)

(define-private (wrap-with-entry-count (achievement {id: uint, name: (string-ascii 50), description: (string-ascii 200), required-entries: uint}))
  {achievement: achievement, entry-count: entry-count}
)

(define-private (check-single-achievement-with-count 
  (data {achievement: {id: uint, name: (string-ascii 50), description: (string-ascii 200), required-entries: uint}, entry-count: uint})
  (current-achievements (list 20 uint)))
  (let (
    (achievement (get achievement data))
    (entry-count (get entry-count data))
  )
    (if (and
      (>= entry-count (get required-entries achievement))
      (not (is-some (index-of? current-achievements (get id achievement))))
    )
      (unwrap-panic (as-max-len? (append current-achievements (get id achievement)) u20))
      current-achievements
    )
  )
)

(define-private (update-streak (user-data {joined-at: uint, entry-count: uint, achievements: (list 20 uint), streaks: {current: uint, longest: uint, last-entry: uint}}))
  (let (
    (current-streak (get current (get streaks user-data)))
    (longest-streak (get longest (get streaks user-data)))
    (last-entry-height (get last-entry (get streaks user-data)))
    (blocks-since-last (if (> block-height last-entry-height)
      (- block-height last-entry-height)
      u0))
    (new-current (if (<= blocks-since-last max-streak-gap)
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

(define-private (validate-content (content (string-utf8 10000)))
  (let ((trimmed-content (string-utf8 content)))
    (and 
      (not (is-eq trimmed-content ""))
      (<= (len trimmed-content) u10000)
      (not (is-eq (len trimmed-content) u0)))
  )
)

;; [Rest of the contract remains unchanged]
