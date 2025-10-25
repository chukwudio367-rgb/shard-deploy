;; ShardDeploy - Blockchain Supply Chain Platform
;; A decentralized supply chain tracking system with granular shard-level verification

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-status (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-invalid-input (err u105))

;; Shipment status enumeration
(define-constant status-created u1)
(define-constant status-in-transit u2)
(define-constant status-delivered u3)
(define-constant status-delayed u4)
(define-constant status-cancelled u5)

;; Data Variables
(define-data-var shipment-nonce uint u0)
(define-data-var shard-nonce uint u0)

;; Data Maps

;; Main shipment tracking
(define-map shipments
    { shipment-id: uint }
    {
        owner: principal,
        origin: (string-ascii 100),
        destination: (string-ascii 100),
        status: uint,
        created-at: uint,
        updated-at: uint,
        estimated-delivery: uint,
        total-shards: uint,
        trust-score: uint
    }
)

;; Individual shard tracking (micro-fragmented verification)
(define-map shards
    { shard-id: uint }
    {
        shipment-id: uint,
        item-description: (string-ascii 200),
        current-location: (string-ascii 100),
        temperature: int,
        humidity: uint,
        last-verified: uint,
        verified-by: principal,
        is-compliant: bool
    }
)

;; Transit checkpoints (Proof-of-Transit records)
(define-map transit-records
    { shard-id: uint, checkpoint-id: uint }
    {
        location: (string-ascii 100),
        timestamp: uint,
        validator: principal,
        sensor-data: (string-ascii 500),
        verified: bool
    }
)

;; Trust scores for participants
(define-map trust-scores
    { participant: principal }
    {
        score: uint,
        completed-shipments: uint,
        delayed-shipments: uint,
        last-updated: uint
    }
)

;; Checkpoint tracking per shard
(define-map shard-checkpoint-count
    { shard-id: uint }
    { count: uint }
)

;; Authorization management
(define-map authorized-validators
    { validator: principal }
    { authorized: bool }
)

;; Read-only functions

(define-read-only (get-shipment (shipment-id uint))
    (map-get? shipments { shipment-id: shipment-id })
)

(define-read-only (get-shard (shard-id uint))
    (map-get? shards { shard-id: shard-id })
)

(define-read-only (get-transit-record (shard-id uint) (checkpoint-id uint))
    (map-get? transit-records { shard-id: shard-id, checkpoint-id: checkpoint-id })
)

(define-read-only (get-trust-score (participant principal))
    (default-to 
        { score: u500, completed-shipments: u0, delayed-shipments: u0, last-updated: u0 }
        (map-get? trust-scores { participant: participant })
    )
)

(define-read-only (is-validator-authorized (validator principal))
    (default-to false 
        (get authorized (map-get? authorized-validators { validator: validator }))
    )
)

(define-read-only (get-shipment-nonce)
    (ok (var-get shipment-nonce))
)

(define-read-only (get-shard-nonce)
    (ok (var-get shard-nonce))
)

;; Private functions

(define-private (increment-checkpoint-count (shard-id uint))
    (let ((current-count (default-to u0 
            (get count (map-get? shard-checkpoint-count { shard-id: shard-id })))))
        (map-set shard-checkpoint-count 
            { shard-id: shard-id }
            { count: (+ current-count u1) }
        )
        (ok (+ current-count u1))
    )
)

;; Public functions

;; Create a new shipment
(define-public (create-shipment 
    (origin (string-ascii 100))
    (destination (string-ascii 100))
    (estimated-delivery uint))
    (let
        (
            (new-shipment-id (+ (var-get shipment-nonce) u1))
            (current-block block-height)
        )
        (asserts! (> (len origin) u0) err-invalid-input)
        (asserts! (> (len destination) u0) err-invalid-input)
        (asserts! (> estimated-delivery current-block) err-invalid-input)
        
        (map-set shipments
            { shipment-id: new-shipment-id }
            {
                owner: tx-sender,
                origin: origin,
                destination: destination,
                status: status-created,
                created-at: current-block,
                updated-at: current-block,
                estimated-delivery: estimated-delivery,
                total-shards: u0,
                trust-score: u1000
            }
        )
        (var-set shipment-nonce new-shipment-id)
        (ok new-shipment-id)
    )
)

;; Add a shard to a shipment
(define-public (add-shard
    (shipment-id uint)
    (item-description (string-ascii 200))
    (initial-location (string-ascii 100)))
    (let
        (
            (shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) err-not-found))
            (new-shard-id (+ (var-get shard-nonce) u1))
        )
        (asserts! (is-eq (get owner shipment) tx-sender) err-unauthorized)
        (asserts! (> (len item-description) u0) err-invalid-input)
        
        (map-set shards
            { shard-id: new-shard-id }
            {
                shipment-id: shipment-id,
                item-description: item-description,
                current-location: initial-location,
                temperature: 0,
                humidity: u50,
                last-verified: block-height,
                verified-by: tx-sender,
                is-compliant: true
            }
        )
        
        (map-set shipments
            { shipment-id: shipment-id }
            (merge shipment { 
                total-shards: (+ (get total-shards shipment) u1),
                updated-at: block-height
            })
        )
        
        (var-set shard-nonce new-shard-id)
        (ok new-shard-id)
    )
)

;; Record transit checkpoint (Proof-of-Transit)
(define-public (record-transit
    (shard-id uint)
    (location (string-ascii 100))
    (sensor-data (string-ascii 500))
    (temperature int)
    (humidity uint))
    (let
        (
            (shard (unwrap! (map-get? shards { shard-id: shard-id }) err-not-found))
            (checkpoint-id (unwrap! (increment-checkpoint-count shard-id) err-invalid-input))
        )
        (asserts! (is-validator-authorized tx-sender) err-unauthorized)
        
        (map-set transit-records
            { shard-id: shard-id, checkpoint-id: checkpoint-id }
            {
                location: location,
                timestamp: block-height,
                validator: tx-sender,
                sensor-data: sensor-data,
                verified: true
            }
        )
        
        (map-set shards
            { shard-id: shard-id }
            (merge shard {
                current-location: location,
                temperature: temperature,
                humidity: humidity,
                last-verified: block-height,
                verified-by: tx-sender
            })
        )
        
        (ok checkpoint-id)
    )
)

;; Update shipment status
(define-public (update-shipment-status
    (shipment-id uint)
    (new-status uint))
    (let
        (
            (shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) err-not-found))
        )
        (asserts! (or (is-eq (get owner shipment) tx-sender)
                      (is-validator-authorized tx-sender)) err-unauthorized)
        (asserts! (and (>= new-status status-created) (<= new-status status-cancelled)) err-invalid-status)
        
        (map-set shipments
            { shipment-id: shipment-id }
            (merge shipment { 
                status: new-status,
                updated-at: block-height
            })
        )
        
        ;; Update trust score if delivered
        (if (is-eq new-status status-delivered)
            (update-trust-score-internal (get owner shipment) true)
            (if (is-eq new-status status-delayed)
                (update-trust-score-internal (get owner shipment) false)
                (ok true)
            )
        )
    )
)

;; Update compliance status for a shard
(define-public (update-shard-compliance
    (shard-id uint)
    (is-compliant bool))
    (let
        (
            (shard (unwrap! (map-get? shards { shard-id: shard-id }) err-not-found))
        )
        (asserts! (is-validator-authorized tx-sender) err-unauthorized)
        
        (map-set shards
            { shard-id: shard-id }
            (merge shard { 
                is-compliant: is-compliant,
                last-verified: block-height,
                verified-by: tx-sender
            })
        )
        (ok true)
    )
)

;; Internal function to update trust scores
(define-private (update-trust-score-internal (participant principal) (successful bool))
    (let
        (
            (current-score (get-trust-score participant))
            (new-completed (if successful 
                (+ (get completed-shipments current-score) u1)
                (get completed-shipments current-score)))
            (new-delayed (if successful
                (get delayed-shipments current-score)
                (+ (get delayed-shipments current-score) u1)))
            (total-shipments (+ new-completed new-delayed))
            (new-score (if (> total-shipments u0)
                (/ (* new-completed u1000) total-shipments)
                u500))
        )
        (map-set trust-scores
            { participant: participant }
            {
                score: new-score,
                completed-shipments: new-completed,
                delayed-shipments: new-delayed,
                last-updated: block-height
            }
        )
        (ok true)
    )
)

;; Authorize a validator (only contract owner)
(define-public (authorize-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-validators
            { validator: validator }
            { authorized: true }
        )
        (ok true)
    )
)

;; Revoke validator authorization (only contract owner)
(define-public (revoke-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-validators
            { validator: validator }
            { authorized: false }
        )
        (ok true)
    )
)

;; Initialize contract with owner as first validator
(begin
    (map-set authorized-validators
        { validator: contract-owner }
        { authorized: true }
    )
)
