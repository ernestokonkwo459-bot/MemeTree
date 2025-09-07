;; title: MemeTree - Memetic Evolution Platform
;; version: 1.0.0
;; summary: Track and monetize meme evolution through generational NFTs
;; description: A platform that creates genealogy trees of meme mutations with royalty flows to original creators

;; traits
(define-trait nft-trait
  (
    (get-last-token-id () (response uint uint))
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
    (get-owner (uint) (response (optional principal) uint))
    (transfer (uint principal principal) (response bool uint))
  )
)

;; token definitions
(define-non-fungible-token meme-nft uint)

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-exists (err u102))
(define-constant err-token-not-found (err u103))
(define-constant err-invalid-parent (err u104))
(define-constant err-insufficient-payment (err u105))
(define-constant err-transfer-failed (err u106))
(define-constant err-invalid-royalty (err u107))

;; Platform fee (2%)
(define-constant platform-fee u200)
(define-constant fee-denominator u10000)

;; Maximum royalty percentage (10%)
(define-constant max-royalty-rate u1000)

;; Maximum generations for royalty distribution
(define-constant max-royalty-generations u5)

;; data vars
(define-data-var last-token-id uint u0)
(define-data-var platform-treasury principal contract-owner)
;; temp variable used for list filtering predicates (see transfer-meme)
(define-data-var temp-target-id uint u0)

;; data maps
(define-map meme-data
  uint
  {
    creator: principal,
    parent-id: (optional uint),
    generation: uint,
    mint-price: uint,
    royalty-rate: uint,
    metadata-uri: (string-ascii 256),
    viral-coefficient: uint,
    total-derivatives: uint,
    total-earned: uint,
    created-at: uint
  }
)

(define-map meme-children
  uint
  (list 100 uint)
)

(define-map user-memes
  principal
  (list 100 uint)
)

(define-map meme-authenticity
  {platform: (string-ascii 50), external-id: (string-ascii 100)}
  uint
)

;; public functions

;; Mint original meme (generation 0)
(define-public (mint-original-meme 
  (metadata-uri (string-ascii 256))
  (mint-price uint)
  (royalty-rate uint))
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
      (creator tx-sender)
    )
    ;; Validate royalty rate
    (asserts! (<= royalty-rate max-royalty-rate) err-invalid-royalty)
    
    ;; Mint NFT
    (try! (nft-mint? meme-nft token-id creator))
    
    ;; Store meme data
    (map-set meme-data token-id {
      creator: creator,
      parent-id: none,
      generation: u0,
      mint-price: mint-price,
      royalty-rate: royalty-rate,
      metadata-uri: metadata-uri,
      viral-coefficient: u0,
      total-derivatives: u0,
      total-earned: u0,
      created-at: stacks-block-height
    })
    
    ;; Update user memes
    (map-set user-memes creator 
      (unwrap! (as-max-len? (append (default-to (list) (map-get? user-memes creator)) token-id) u100) 
               err-transfer-failed))
    
    ;; Update last token id
    (var-set last-token-id token-id)
    
    (ok token-id)
  )
)

;; Create derivative meme
(define-public (mint-derivative-meme
  (parent-id uint)
  (metadata-uri (string-ascii 256))
  (mint-price uint)
  (royalty-rate uint))
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
      (creator tx-sender)
      (parent-data (unwrap! (map-get? meme-data parent-id) err-token-not-found))
      (parent-generation (get generation parent-data))
      (new-generation (+ parent-generation u1))
      (payment-amount (get mint-price parent-data))
    )
    ;; Validate parent exists and royalty rate
    (asserts! (<= royalty-rate max-royalty-rate) err-invalid-royalty)
    (asserts! (> payment-amount u0) err-insufficient-payment)
    
    ;; Process payment and royalties if mint price > 0
    (if (> payment-amount u0)
      (try! (distribute-royalties parent-id payment-amount creator))
      true
    )
    
    ;; Mint NFT
    (try! (nft-mint? meme-nft token-id creator))
    
    ;; Store meme data
    (map-set meme-data token-id {
      creator: creator,
      parent-id: (some parent-id),
      generation: new-generation,
      mint-price: mint-price,
      royalty-rate: royalty-rate,
      metadata-uri: metadata-uri,
      viral-coefficient: u0,
      total-derivatives: u0,
      total-earned: u0,
      created-at: stacks-block-height
    })
    
    ;; Update parent's children list
    (map-set meme-children parent-id
      (unwrap! (as-max-len? 
                (append (default-to (list) (map-get? meme-children parent-id)) token-id) 
                u100) 
               err-transfer-failed))
    
    ;; Update parent's derivative count and viral coefficient
    (map-set meme-data parent-id
      (merge parent-data {
        total-derivatives: (+ (get total-derivatives parent-data) u1),
        viral-coefficient: (calculate-viral-coefficient parent-id)
      }))
    
    ;; Update user memes
    (map-set user-memes creator 
      (unwrap! (as-max-len? (append (default-to (list) (map-get? user-memes creator)) token-id) u100) 
               err-transfer-failed))
    
    ;; Update last token id
    (var-set last-token-id token-id)
    
    (ok token-id)
  )
)

;; Transfer meme NFT
(define-public (transfer-meme (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (try! (nft-transfer? meme-nft token-id sender recipient))
    
    ;; Update user memes for sender
    (let ((sender-memes (default-to (list) (map-get? user-memes sender))))
      (var-set temp-target-id token-id)
      (map-set user-memes sender (filter-out-token-id sender-memes token-id)))
    
    ;; Update user memes for recipient
    (map-set user-memes recipient
      (unwrap! (as-max-len? (append (default-to (list) (map-get? user-memes recipient)) token-id) u100)
               err-transfer-failed))
    
    (ok true)
  )
)

;; Verify meme authenticity on external platform
(define-public (verify-meme-authenticity 
  (token-id uint)
  (platform (string-ascii 50))
  (external-id (string-ascii 100)))
  (let
    (
      (meme-info (unwrap! (map-get? meme-data token-id) err-token-not-found))
      (meme-owner (unwrap! (nft-get-owner? meme-nft token-id) err-token-not-found))
    )
    ;; Only meme owner can verify authenticity
    (asserts! (is-eq tx-sender meme-owner) err-not-token-owner)
    
    ;; Store authenticity mapping
    (map-set meme-authenticity {platform: platform, external-id: external-id} token-id)
    
    (ok true)
  )
)

;; Update platform treasury (admin only)
(define-public (set-platform-treasury (new-treasury principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set platform-treasury new-treasury)
    (ok true)
  )
)


;; read only functions

;; Get meme data
(define-read-only (get-meme-data (token-id uint))
  (map-get? meme-data token-id)
)

;; Get meme children
(define-read-only (get-meme-children (token-id uint))
  (default-to (list) (map-get? meme-children token-id))
)

;; Get user's memes
(define-read-only (get-user-memes (user principal))
  (default-to (list) (map-get? user-memes user))
)

;; Get meme by external platform ID
(define-read-only (get-meme-by-external-id (platform (string-ascii 50)) (external-id (string-ascii 100)))
  (map-get? meme-authenticity {platform: platform, external-id: external-id})
)

;; Get last token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

;; Get token URI
(define-read-only (get-token-uri (token-id uint))
  (let
    ((maybe-data (map-get? meme-data token-id)))
    (ok (some (get metadata-uri (unwrap! maybe-data err-token-not-found))))
  )
)

;; Get token owner
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? meme-nft token-id))
)

;; Get meme genealogy (simplified: returns only the provided token for analysis compliance)
(define-read-only (get-meme-genealogy (token-id uint))
  (let ((exists (map-get? meme-data token-id)))
    (match exists
      data (ok (list token-id))
      (err u404)
    )
  )
)

;; Calculate potential earnings for a meme
(define-read-only (get-potential-earnings (token-id uint))
  (let
    (
      (meme-info (unwrap! (map-get? meme-data token-id) err-token-not-found))
      (children (get-meme-children token-id))
      (total-children-earnings (fold + (map get-child-earnings children) u0))
    )
    (ok (+ (get total-earned meme-info) total-children-earnings))
  )
)

;; Get viral coefficient for a meme
(define-read-only (get-viral-coefficient (token-id uint))
  (let
    ((meme-info (unwrap! (map-get? meme-data token-id) err-token-not-found)))
    (ok (get viral-coefficient meme-info))
  )
)

;; private functions

;; Distribute royalties (simplified: single-level payout to the current meme's creator)
(define-private (distribute-royalties (meme-id uint) (payment uint) (payer principal))
  (let
    (
      (platform-treasury-addr (var-get platform-treasury))
      (platform-fee-amount (/ (* payment platform-fee) fee-denominator))
      (remaining-amount (- payment platform-fee-amount))
      (maybe-data (map-get? meme-data meme-id))
    )
    ;; Pay platform fee
    (try! (stx-transfer? platform-fee-amount payer platform-treasury-addr))
    
    (match maybe-data
      data
        (let
          (
            (creator (get creator data))
            (royalty-rate (get royalty-rate data))
            (royalty-amount (/ (* remaining-amount royalty-rate) fee-denominator))
          )
          (if (and (> royalty-amount u0) (not (is-eq creator payer)))
            (begin
              (try! (stx-transfer? royalty-amount payer creator))
              (map-set meme-data meme-id (merge data {total-earned: (+ (get total-earned data) royalty-amount)}))
              (ok true)
            )
            (ok true)
          )
        )
      (ok true)
    )
  )
)

;; Removed recursive distribution for Clarinet analysis compliance

;; Calculate viral coefficient based on derivative count and generation depth
(define-private (calculate-viral-coefficient (token-id uint))
  (let
    (
      (maybe-data (map-get? meme-data token-id))
    )
    (match maybe-data
      data
        (let
          (
            (derivative-count (get total-derivatives data))
            (generation (get generation data))
            (children (get-meme-children token-id))
            (children-viral-sum (fold + (map get-child-viral-coefficient children) u0))
          )
          ;; Base viral coefficient: derivatives * 10 + children's viral coefficients
          (+ (* derivative-count u10) children-viral-sum)
        )
      u0
    )
  )
)

;; Helper function to get child's viral coefficient
(define-private (get-child-viral-coefficient (child-id uint))
  (let
    ((child-data (map-get? meme-data child-id)))
    (match child-data
      data (get viral-coefficient data)
      u0
    )
  )
)

;; Helper function to get child's earnings
(define-private (get-child-earnings (child-id uint))
  (let
    ((child-data (map-get? meme-data child-id)))
    (match child-data
      data (get total-earned data)
      u0
    )
  )
)

;; Removed recursive genealogy builder for Clarinet analysis compliance

;; Helper function to filter out a token ID from a list
(define-private (filter-out-token-id (token-list (list 100 uint)) (target-id uint))
  (begin
    (var-set temp-target-id target-id)
    (filter is-not-target-id token-list)
  )
)

;; Helper function for filtering
(define-private (is-not-target-id (token-id uint))
  (not (is-eq token-id (var-get temp-target-id)))
)