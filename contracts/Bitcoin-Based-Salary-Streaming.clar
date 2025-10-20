(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_STREAM_NOT_ACTIVE (err u410))
(define-constant ERR_STREAM_ALREADY_STOPPED (err u411))
(define-constant ERR_FUTURE_START_TIME (err u412))
(define-constant ERR_ADJUSTMENT_NOT_FOUND (err u413))
(define-constant ERR_ADJUSTMENT_ALREADY_PROCESSED (err u414))
(define-constant ERR_ADJUSTMENT_EXPIRED (err u415))
(define-constant ERR_INVALID_ADJUSTMENT (err u416))

(define-constant PRECISION u1000000)
(define-constant SECONDS_PER_BLOCK u600)

(define-data-var next-stream-id uint u1)
(define-data-var next-adjustment-id uint u1)

(define-map streams
  uint
  {
    employer: principal,
    employee: principal,
    salary-rate: uint,
    start-time: uint,
    end-time: (optional uint),
    total-funded: uint,
    total-withdrawn: uint,
    is-active: bool
  }
)

(define-map employer-streams principal (list 100 uint))
(define-map employee-streams principal (list 100 uint))

(define-map stream-balances uint uint)

(define-map stream-beneficiaries uint principal)

(define-map salary-adjustments
  uint
  {
    stream-id: uint,
    old-rate: uint,
    new-rate: uint,
    adjustment-type: (string-ascii 20),
    proposed-by: principal,
    proposed-at: uint,
    expires-at: uint,
    approved: bool,
    processed: bool,
    effective-time: (optional uint),
    reason: (string-ascii 100)
  }
)

(define-map stream-adjustments uint (list 50 uint))

(define-private (get-current-time)
  (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1)))
)

(define-private (add-to-list (item uint) (lst (list 100 uint)))
  (unwrap-panic (as-max-len? (append lst item) u100))
)

(define-public (create-salary-stream 
  (employee principal) 
  (salary-rate-per-second uint) 
  (start-time uint)
  (initial-funding uint))
  (let (
    (stream-id (var-get next-stream-id))
    (current-time (get-current-time))
  )
    (asserts! (> salary-rate-per-second u0) ERR_INVALID_AMOUNT)
    (asserts! (> initial-funding u0) ERR_INVALID_AMOUNT)
    (asserts! (>= start-time current-time) ERR_FUTURE_START_TIME)
    
    (try! (stx-transfer? initial-funding tx-sender (as-contract tx-sender)))
    
    (map-set streams stream-id {
      employer: tx-sender,
      employee: employee,
      salary-rate: salary-rate-per-second,
      start-time: start-time,
      end-time: none,
      total-funded: initial-funding,
      total-withdrawn: u0,
      is-active: true
    })
    
    (map-set stream-balances stream-id initial-funding)
    
    (map-set employer-streams tx-sender 
      (add-to-list stream-id 
        (default-to (list) (map-get? employer-streams tx-sender))))
    
    (map-set employee-streams employee 
      (add-to-list stream-id 
        (default-to (list) (map-get? employee-streams employee))))
    
    (var-set next-stream-id (+ stream-id u1))
    (ok stream-id)
  )
)

(define-public (fund-stream (stream-id uint) (amount uint))
  (let (
    (stream-data (unwrap! (map-get? streams stream-id) ERR_NOT_FOUND))
    (current-balance (default-to u0 (map-get? stream-balances stream-id)))
  )
    (asserts! (is-eq tx-sender (get employer stream-data)) ERR_UNAUTHORIZED)
    (asserts! (get is-active stream-data) ERR_STREAM_NOT_ACTIVE)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set streams stream-id 
      (merge stream-data { total-funded: (+ (get total-funded stream-data) amount) }))
    
    (map-set stream-balances stream-id (+ current-balance amount))
    (ok true)
  )
)

(define-private (calculate-earned-amount (stream-data {employer: principal, employee: principal, salary-rate: uint, start-time: uint, end-time: (optional uint), total-funded: uint, total-withdrawn: uint, is-active: bool}))
  (let (
    (current-time (get-current-time))
    (start-time (get start-time stream-data))
    (end-time (default-to current-time (get end-time stream-data)))
    (effective-end-time (if (< end-time current-time) end-time current-time))
    (elapsed-seconds (if (> effective-end-time start-time) (- effective-end-time start-time) u0))
    (earned-amount (* elapsed-seconds (get salary-rate stream-data)))
  )
    (if (<= start-time current-time) earned-amount u0)
  )
)

(define-read-only (get-withdrawable-amount (stream-id uint))
  (let (
    (stream-data (unwrap! (map-get? streams stream-id) ERR_NOT_FOUND))
    (earned-amount (calculate-earned-amount stream-data))
    (already-withdrawn (get total-withdrawn stream-data))
    (available-balance (default-to u0 (map-get? stream-balances stream-id)))
  )
    (let ((pending-amount (if (> earned-amount already-withdrawn) 
                            (- earned-amount already-withdrawn) u0)))
      (ok (if (< pending-amount available-balance) pending-amount available-balance))
    )
  )
)

(define-public (withdraw-salary (stream-id uint))
  (let (
    (stream-data (unwrap! (map-get? streams stream-id) ERR_NOT_FOUND))
    (withdrawable-amount (unwrap! (get-withdrawable-amount stream-id) ERR_NOT_FOUND))
    (current-balance (default-to u0 (map-get? stream-balances stream-id)))
    (maybe-beneficiary (map-get? stream-beneficiaries stream-id))
    (authorized (or (is-eq tx-sender (get employee stream-data))
                    (match maybe-beneficiary b (is-eq tx-sender b) false)))
    (payout (default-to (get employee stream-data) maybe-beneficiary))
  )
    (asserts! authorized ERR_UNAUTHORIZED)
    (asserts! (get is-active stream-data) ERR_STREAM_NOT_ACTIVE)
    (asserts! (> withdrawable-amount u0) ERR_INSUFFICIENT_FUNDS)
    
    (try! (stx-transfer? withdrawable-amount (as-contract tx-sender) payout))
    
    (map-set streams stream-id 
      (merge stream-data { 
        total-withdrawn: (+ (get total-withdrawn stream-data) withdrawable-amount) 
      }))
    
    (map-set stream-balances stream-id (- current-balance withdrawable-amount))
    (ok withdrawable-amount)
  )
)

(define-public (stop-stream (stream-id uint))
  (let (
    (stream-data (unwrap! (map-get? streams stream-id) ERR_NOT_FOUND))
    (current-time (get-current-time))
  )
    (asserts! (is-eq tx-sender (get employer stream-data)) ERR_UNAUTHORIZED)
    (asserts! (get is-active stream-data) ERR_STREAM_NOT_ACTIVE)
    
    (map-set streams stream-id 
      (merge stream-data { 
        end-time: (some current-time),
        is-active: false
      }))
    (ok true)
  )
)

(define-public (set-stream-beneficiary (stream-id uint) (beneficiary (optional principal)))
  (let ((stream-data (unwrap! (map-get? streams stream-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get employee stream-data)) ERR_UNAUTHORIZED)
    (if (is-some beneficiary)
      (begin
        (map-set stream-beneficiaries stream-id (unwrap-panic beneficiary))
        (ok true))
      (begin
        (map-delete stream-beneficiaries stream-id)
        (ok true))
    )
  )
)

(define-public (emergency-withdraw (stream-id uint))
  (let (
    (stream-data (unwrap! (map-get? streams stream-id) ERR_NOT_FOUND))
    (current-balance (default-to u0 (map-get? stream-balances stream-id)))
    (earned-amount (calculate-earned-amount stream-data))
    (total-withdrawn (get total-withdrawn stream-data))
    (employee-owed (if (> earned-amount total-withdrawn) 
                     (- earned-amount total-withdrawn) u0))
    (employer-refund (if (> current-balance employee-owed) 
                       (- current-balance employee-owed) u0))
  )
    (asserts! (is-eq tx-sender (get employer stream-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get is-active stream-data)) ERR_STREAM_ALREADY_STOPPED)
    
    (if (> employee-owed u0)
      (try! (stx-transfer? employee-owed (as-contract tx-sender) (get employee stream-data)))
      true)
    
    (if (> employer-refund u0)
      (try! (stx-transfer? employer-refund (as-contract tx-sender) (get employer stream-data)))
      true)
    
    (map-set streams stream-id 
      (merge stream-data { 
        total-withdrawn: (+ total-withdrawn employee-owed)
      }))
    
    (map-set stream-balances stream-id u0)
    (ok { employee-paid: employee-owed, employer-refund: employer-refund })
  )
)

(define-public (propose-salary-adjustment 
  (stream-id uint)
  (new-rate uint)
  (adjustment-type (string-ascii 20))
  (reason (string-ascii 100))
  (validity-days uint))
  (let (
    (stream-data (unwrap! (map-get? streams stream-id) ERR_NOT_FOUND))
    (adjustment-id (var-get next-adjustment-id))
    (current-time (get-current-time))
    (current-adjustments (default-to (list) (map-get? stream-adjustments stream-id)))
  )
    (asserts! (is-eq tx-sender (get employer stream-data)) ERR_UNAUTHORIZED)
    (asserts! (get is-active stream-data) ERR_STREAM_NOT_ACTIVE)
    (asserts! (> new-rate u0) ERR_INVALID_AMOUNT)
    (asserts! (> validity-days u0) ERR_INVALID_ADJUSTMENT)
    
    (map-set salary-adjustments adjustment-id {
      stream-id: stream-id,
      old-rate: (get salary-rate stream-data),
      new-rate: new-rate,
      adjustment-type: adjustment-type,
      proposed-by: tx-sender,
      proposed-at: current-time,
      expires-at: (+ current-time (* validity-days u86400)),
      approved: false,
      processed: false,
      effective-time: none,
      reason: reason
    })
    
    (map-set stream-adjustments stream-id 
      (unwrap-panic (as-max-len? (append current-adjustments adjustment-id) u50)))
    
    (var-set next-adjustment-id (+ adjustment-id u1))
    (ok adjustment-id)
  )
)

(define-public (approve-salary-adjustment (adjustment-id uint))
  (let (
    (adjustment (unwrap! (map-get? salary-adjustments adjustment-id) ERR_ADJUSTMENT_NOT_FOUND))
    (stream-data (unwrap! (map-get? streams (get stream-id adjustment)) ERR_NOT_FOUND))
    (current-time (get-current-time))
  )
    (asserts! (is-eq tx-sender (get employee stream-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get processed adjustment)) ERR_ADJUSTMENT_ALREADY_PROCESSED)
    (asserts! (< current-time (get expires-at adjustment)) ERR_ADJUSTMENT_EXPIRED)
    
    (map-set salary-adjustments adjustment-id 
      (merge adjustment { 
        approved: true,
        processed: true,
        effective-time: (some current-time)
      }))
    
    (map-set streams (get stream-id adjustment) 
      (merge stream-data { salary-rate: (get new-rate adjustment) }))
    
    (ok true)
  )
)

(define-public (reject-salary-adjustment (adjustment-id uint))
  (let (
    (adjustment (unwrap! (map-get? salary-adjustments adjustment-id) ERR_ADJUSTMENT_NOT_FOUND))
    (stream-data (unwrap! (map-get? streams (get stream-id adjustment)) ERR_NOT_FOUND))
    (current-time (get-current-time))
  )
    (asserts! (is-eq tx-sender (get employee stream-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get processed adjustment)) ERR_ADJUSTMENT_ALREADY_PROCESSED)
    (asserts! (< current-time (get expires-at adjustment)) ERR_ADJUSTMENT_EXPIRED)
    
    (map-set salary-adjustments adjustment-id 
      (merge adjustment { 
        approved: false,
        processed: true
      }))
    
    (ok true)
  )
)

(define-public (cancel-salary-adjustment (adjustment-id uint))
  (let (
    (adjustment (unwrap! (map-get? salary-adjustments adjustment-id) ERR_ADJUSTMENT_NOT_FOUND))
    (stream-data (unwrap! (map-get? streams (get stream-id adjustment)) ERR_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get employer stream-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get processed adjustment)) ERR_ADJUSTMENT_ALREADY_PROCESSED)
    
    (map-set salary-adjustments adjustment-id 
      (merge adjustment { processed: true }))
    
    (ok true)
  )
)

(define-read-only (get-stream (stream-id uint))
  (map-get? streams stream-id)
)

(define-read-only (get-stream-balance (stream-id uint))
  (map-get? stream-balances stream-id)
)

(define-read-only (get-employer-streams (employer principal))
  (map-get? employer-streams employer)
)

(define-read-only (get-employee-streams (employee principal))
  (map-get? employee-streams employee)
)

(define-read-only (get-stream-beneficiary (stream-id uint))
  (map-get? stream-beneficiaries stream-id)
)

(define-read-only (get-stream-status (stream-id uint))
  (let (
    (stream-data (unwrap! (map-get? streams stream-id) ERR_NOT_FOUND))
    (withdrawable (unwrap! (get-withdrawable-amount stream-id) ERR_NOT_FOUND))
    (current-balance (default-to u0 (map-get? stream-balances stream-id)))
    (earned-amount (calculate-earned-amount stream-data))
  )
    (ok {
      stream-info: stream-data,
      current-balance: current-balance,
      earned-amount: earned-amount,
      withdrawable-amount: withdrawable,
      is-funded: (> current-balance u0)
    })
  )
)

(define-read-only (get-next-stream-id)
  (var-get next-stream-id)
)

(define-read-only (get-salary-adjustment (adjustment-id uint))
  (map-get? salary-adjustments adjustment-id)
)

(define-read-only (get-stream-adjustments (stream-id uint))
  (map-get? stream-adjustments stream-id)
)

(define-read-only (get-pending-adjustments (stream-id uint))
  (let (
    (adjustments (default-to (list) (map-get? stream-adjustments stream-id)))
    (current-time (get-current-time))
  )
    (filter is-pending-adjustment adjustments)
  )
)

(define-private (is-pending-adjustment (adjustment-id uint))
  (match (map-get? salary-adjustments adjustment-id)
    adjustment (and 
      (not (get processed adjustment))
      (< (get-current-time) (get expires-at adjustment))
    )
    false
  )
)

(define-read-only (get-adjustment-history (stream-id uint))
  (let (
    (adjustments (default-to (list) (map-get? stream-adjustments stream-id)))
  )
    (map get-adjustment-details adjustments)
  )
)

(define-private (get-adjustment-details (adjustment-id uint))
  (map-get? salary-adjustments adjustment-id)
)

(define-read-only (calculate-salary-change-percentage (adjustment-id uint))
  (match (map-get? salary-adjustments adjustment-id)
    adjustment (let (
      (old-rate (get old-rate adjustment))
      (new-rate (get new-rate adjustment))
      (change (* (if (> new-rate old-rate) 
                   (- new-rate old-rate) 
                   (- old-rate new-rate)) u10000))
    )
      (if (> old-rate u0)
        (ok (/ change old-rate))
        ERR_INVALID_ADJUSTMENT
      )
    )
    ERR_ADJUSTMENT_NOT_FOUND
  )
)

(define-read-only (get-next-adjustment-id)
  (var-get next-adjustment-id)
)
