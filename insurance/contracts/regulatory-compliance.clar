;; Regulatory Compliance Module

;; Define data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var compliance-officer principal tx-sender)

;; Define data maps
(define-map kyc-status { user: principal } { status: (string-ascii 20), expiration: uint })
(define-map aml-status { user: principal } { status: (string-ascii 20), last-check: uint })
(define-map local-regulations { region: (string-ascii 50) } { min-age: uint, max-coverage: uint })
(define-map user-region { user: principal } { region: (string-ascii 50) })

;; Define constants
(define-constant kyc-valid-period u31536000) ;; 1 year in seconds

;; Error constants
(define-constant err-unauthorized (err u401))
(define-constant err-not-kyc-approved (err u402))
(define-constant err-aml-check-failed (err u403))
(define-constant err-regulation-violation (err u404))

;; Helper functions
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner)))

(define-private (is-compliance-officer)
  (is-eq tx-sender (var-get compliance-officer)))

;; KYC functions
(define-public (set-kyc-status (user principal) (status (string-ascii 20)))
  (begin
    (asserts! (is-compliance-officer) err-unauthorized)
    (ok (map-set kyc-status { user: user } { status: status, expiration: (+ block-height kyc-valid-period) }))))

(define-public (check-kyc-status (user principal))
  (match (map-get? kyc-status { user: user })
    kyc-data (ok (and (is-eq (get status kyc-data) "approved")
                      (< block-height (get expiration kyc-data))))
    (ok false)))

;; AML functions
(define-public (set-aml-status (user principal) (status (string-ascii 20)))
  (begin
    (asserts! (is-compliance-officer) err-unauthorized)
    (ok (map-set aml-status { user: user } { status: status, last-check: block-height }))))

(define-public (check-aml-status (user principal))
  (match (map-get? aml-status { user: user })
    aml-data (ok (is-eq (get status aml-data) "cleared"))
    (ok false)))

;; Local regulation functions
(define-public (set-local-regulation (region (string-ascii 50)) (min-age uint) (max-coverage uint))
  (begin
    (asserts! (is-compliance-officer) err-unauthorized)
    (ok (map-set local-regulations { region: region } { min-age: min-age, max-coverage: max-coverage }))))

(define-public (set-user-region (user principal) (region (string-ascii 50)))
  (begin
    (asserts! (is-compliance-officer) err-unauthorized)
    (ok (map-set user-region { user: user } { region: region }))))

;; Compliance check function
(define-public (check-compliance (user principal) (age uint) (coverage uint))
  (begin
    (asserts! (is-some (map-get? user-region { user: user })) err-unauthorized)
    (asserts! (unwrap! (check-kyc-status user) err-not-kyc-approved) err-not-kyc-approved)
    (asserts! (unwrap! (check-aml-status user) err-aml-check-failed) err-aml-check-failed)
    (match (map-get? local-regulations { region: (get region (unwrap! (map-get? user-region { user: user }) err-unauthorized)) })
      regulation (begin
        (asserts! (>= age (get min-age regulation)) err-regulation-violation)
        (asserts! (<= coverage (get max-coverage regulation)) err-regulation-violation)
        (ok true))
      err-regulation-violation)))

;; Administrative functions
(define-public (set-compliance-officer (new-officer principal))
  (begin
    (asserts! (is-contract-owner) err-unauthorized)
    (ok (var-set compliance-officer new-officer))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) err-unauthorized)
    (ok (var-set contract-owner new-owner))))