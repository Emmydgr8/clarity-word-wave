;; WordWave Contract
;; Journal entries and mood tracking with achievements on Stacks

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-content (err u103))
(define-constant err-invalid-mood (err u104))
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

[... rest of original maps ...]

;; Private Functions
(define-private (check-achievements (user-data {joined-at: uint, entry-count: uint, achievements: (list 20 uint), streaks: {current: uint, longest: uint, last-entry: uint}}))
  (let (
    (entry-count (get entry-count user-data))
    (current-achievements (get achievements user-data))
  )
    (fold check-single-achievement-with-count
      (map-with-entry-count (var-get achievement-definitions) entry-count)
      current-achievements)
  )
)

(define-private (map-with-entry-count (achievements (list 5 {id: uint, name: (string-ascii 50), description: (string-ascii 200), required-entries: uint})) (count uint))
  (map wrap-with-entry-count achievements)
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
    (blocks-since-last (- block-height last-entry-height))
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
  (and 
    (not (is-eq content ""))
    (<= (len content) u10000))
)

(define-private (validate-mood (mood (string-ascii 20)))
  (and 
    (not (is-eq mood ""))
    (<= (len mood) u20))
)

;; Public Functions
(define-public (initialize-user)
  (begin
    (asserts! (is-none (map-get? users tx-sender)) (err u105))
    (ok (map-set users tx-sender {
      joined-at: block-height,
      entry-count: u0,
      achievements: (list 20 uint),
      streaks: {
        current: u0,
        longest: u0,
        last-entry: u0
      }
    }))
  )
)

(define-public (create-entry (content (string-utf8 10000)) (prompt-id uint) (mood (string-ascii 20)))
  (begin
    (asserts! (validate-content content) err-invalid-content)
    (asserts! (validate-mood mood) err-invalid-mood)
    (let (
      (user-data (unwrap! (map-get? users tx-sender) (err u106)))
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
)

[... rest of original functions ...]
