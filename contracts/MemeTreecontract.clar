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
      (meme-data (unwrap! (map-get? meme-data token-id) err-token-not-found))
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