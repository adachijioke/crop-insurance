;; Weather Data Integration Smart Contract

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-already-initialized (err u101))
(define-constant err-invalid-parameter (err u102))
(define-constant err-oracle-already-exists (err u103))
(define-constant err-oracle-not-found (err u104))

;; Define data variables
(define-data-var contract-initialized bool false)

;; Define maps
(define-map oracles
  { oracle-id: uint }
  { name: (string-ascii 64), active: bool }
)

(define-map weather-data
  { oracle-id: uint, timestamp: uint }
  {
    rainfall: uint,
    temperature: int,
    wind-speed: uint,
    humidity: uint
  }
)

;; Initialize contract
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (not (var-get contract-initialized)) err-already-initialized)
    (var-set contract-initialized true)
    (ok true)
  )
)

;; Add a new oracle
(define-public (add-oracle (oracle-id uint) (name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (is-none (map-get? oracles { oracle-id: oracle-id })) err-oracle-already-exists)
    (map-set oracles
      { oracle-id: oracle-id }
      { name: name, active: true }
    )
    (ok true)
  )
)

;; Deactivate an oracle
(define-public (deactivate-oracle (oracle-id uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (match (map-get? oracles { oracle-id: oracle-id })
      oracle (begin
        (map-set oracles
          { oracle-id: oracle-id }
          (merge oracle { active: false })
        )
        (ok true)
      )
      err-oracle-not-found
    )
  )
)

;; Submit weather data
(define-public (submit-weather-data (oracle-id uint) (timestamp uint) (rainfall uint) (temperature int) (wind-speed uint) (humidity uint))
  (begin
    ;; Check if the oracle exists and is active
    (match (map-get? oracles { oracle-id: oracle-id })
      oracle (asserts! (get active oracle) err-unauthorized)
      err-oracle-not-found
    )
    
    ;; Validate input parameters
    (asserts! (and (< rainfall u1000000) (> temperature i-100) (< temperature i100) (< wind-speed u1000) (< humidity u101)) err-invalid-parameter)
    
    ;; Store the weather data
    (map-set weather-data
      { oracle-id: oracle-id, timestamp: timestamp }
      {
        rainfall: rainfall,
        temperature: temperature,
        wind-speed: wind-speed,
        humidity: humidity
      }
    )
    (ok true)
  )
)

;; Get the latest weather data from a specific oracle
(define-read-only (get-latest-weather-data (oracle-id uint))
  (let
    (
      (latest-timestamp (default-to u0 (get-latest-timestamp oracle-id)))
    )
    (map-get? weather-data { oracle-id: oracle-id, timestamp: latest-timestamp })
  )
)

;; Helper function to get the latest timestamp for an oracle
(define-private (get-latest-timestamp (oracle-id uint))
  (fold max-uint
    (map-keys weather-data)
    u0
  )
)

;; Helper function to get the maximum of two uints
(define-private (max-uint (a { oracle-id: uint, timestamp: uint }) (b uint))
  (if (and (is-eq (get oracle-id a) oracle-id) (> (get timestamp a) b))
    (get timestamp a)
    b
  )
)

;; Get weather data for a specific oracle and timestamp
(define-read-only (get-weather-data (oracle-id uint) (timestamp uint))
  (map-get? weather-data { oracle-id: oracle-id, timestamp: timestamp })
)

;; Get oracle information
(define-read-only (get-oracle-info (oracle-id uint))
  (map-get? oracles { oracle-id: oracle-id })
)

