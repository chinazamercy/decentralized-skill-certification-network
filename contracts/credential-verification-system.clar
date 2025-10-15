;; Credential Verification System Smart Contract
;; Issues blockchain-verified skill credentials, manages credential authenticity,
;; enables employer verification, tracks career progression, and maintains professional reputation scores

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-CREDENTIAL-NOT-FOUND (err u2))
(define-constant ERR-INVALID-VERIFICATION (err u3))
(define-constant ERR-ALREADY-EXISTS (err u4))
(define-constant ERR-INVALID-SCORE (err u5))
(define-constant ERR-EXPIRED-CREDENTIAL (err u6))
(define-constant ERR-INSUFFICIENT-PRIVILEGES (err u7))
(define-constant ERR-INVALID-STATUS (err u8))
(define-constant ERR-REPUTATION-THRESHOLD (err u9))
(define-constant ERR-VERIFICATION-FAILED (err u10))

(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-CREDENTIALS u10000)
(define-constant MIN-REPUTATION-SCORE u30)
(define-constant CREDENTIAL-VALIDITY-YEARS u3)
(define-constant MAX-SKILL-CATEGORIES u50)
(define-constant VERIFICATION-FEE u1000) ;; in microSTX

;; Data Maps and Variables

;; Digital credential management
(define-map digital-credentials
  { credential-id: uint }
  {
    holder: principal,
    skill-category: (string-ascii 30),
    skill-name: (string-ascii 50),
    competency-level: uint, ;; 1-5 scale
    assessment-score: uint,
    issuing-experts: (list 3 principal),
    issue-date: uint,
    expiry-date: uint,
    credential-hash: (string-ascii 64),
    verification-count: uint,
    active-status: bool,
    credential-type: (string-ascii 20), ;; certificate, badge, endorsement
    metadata: (string-ascii 200)
  })

;; Professional profiles
(define-map professional-profiles
  { profile-id: principal }
  {
    name: (string-ascii 50),
    credentials: (list 20 uint),
    reputation-score: uint,
    total-verifications: uint,
    career-level: (string-ascii 20),
    primary-skills: (list 10 (string-ascii 30)),
    profile-created: uint,
    last-updated: uint,
    verification-history: (list 50 uint),
    endorsements: (list 10 principal)
  })

;; Employer verification records
(define-map employer-verifications
  { verification-id: uint }
  {
    employer: principal,
    credential-id: uint,
    candidate: principal,
    verification-purpose: (string-ascii 50),
    verification-date: uint,
    verification-result: bool,
    confidence-score: uint,
    additional-checks: (list 3 (string-ascii 30)),
    verification-notes: (string-ascii 200),
    follow-up-required: bool
  })

;; Credential authenticity tracking
(define-map authenticity-records
  { record-id: uint }
  {
    credential-id: uint,
    verification-method: (string-ascii 30),
    cryptographic-proof: (string-ascii 128),
    witness-signatures: (list 5 principal),
    timestamp-proof: uint,
    blockchain-anchor: (string-ascii 64),
    integrity-verified: bool,
    audit-trail: (list 10 uint)
  })

;; Reputation and endorsement system
(define-map reputation-records
  { user-id: principal }
  {
    base-reputation: uint,
    skill-endorsements: (list 20 uint),
    peer-ratings: (list 10 uint),
    employer-feedback: (list 15 uint),
    community-contributions: uint,
    reputation-factors: (list 5 uint),
    last-reputation-update: uint,
    reputation-trend: (string-ascii 10) ;; rising, stable, declining
  })

;; Career progression tracking
(define-map career-progressions
  { progression-id: uint }
  {
    professional: principal,
    skill-category: (string-ascii 30),
    progression-milestones: (list 10 uint),
    competency-improvements: (list 10 uint),
    certification-timeline: (list 15 uint),
    career-trajectory: (string-ascii 20),
    growth-metrics: (list 5 uint),
    next-skill-recommendations: (list 5 (string-ascii 30))
  })

;; Employer integration settings
(define-map employer-integrations
  { employer-id: principal }
  {
    company-name: (string-ascii 50),
    integration-type: (string-ascii 20),
    api-access-level: uint,
    verification-preferences: (list 5 (string-ascii 30)),
    auto-verification-enabled: bool,
    integration-date: uint,
    usage-statistics: (list 5 uint),
    subscription-tier: (string-ascii 20)
  })

;; Counter variables
(define-data-var next-credential-id uint u1)
(define-data-var next-verification-id uint u1)
(define-data-var next-record-id uint u1)
(define-data-var next-progression-id uint u1)
(define-data-var total-credentials uint u0)
(define-data-var system-trust-score uint u90) ;; out of 100

;; Authorization lists
(define-data-var credential-issuers (list 20 principal) (list CONTRACT-OWNER))
(define-data-var verified-employers (list 100 principal) (list))
(define-data-var reputation-validators (list 10 principal) (list CONTRACT-OWNER))

;; Private Functions

(define-private (is-credential-issuer (user principal))
  (is-some (index-of (var-get credential-issuers) user)))

(define-private (is-verified-employer (employer principal))
  (is-some (index-of (var-get verified-employers) employer)))

(define-private (is-reputation-validator (user principal))
  (is-some (index-of (var-get reputation-validators) user)))

(define-private (calculate-credential-hash (holder principal) (skill (string-ascii 50)) (score uint))
  ;; Simplified hash calculation - in real implementation would use cryptographic hashing
  (int-to-ascii (+ score (len skill) stacks-block-height)))

(define-private (validate-competency-level (level uint))
  (and (>= level u1) (<= level u5)))

(define-private (is-credential-valid (credential-id uint))
  (let (
    (credential (map-get? digital-credentials { credential-id: credential-id }))
  )
    (match credential
      credential-data (and 
        (get active-status credential-data)
        (> (get expiry-date credential-data) stacks-block-height))
      false)))

(define-private (calculate-reputation-score (user principal))
  (let (
    (reputation-data (map-get? reputation-records { user-id: user }))
    (profile-data (map-get? professional-profiles { profile-id: user }))
  )
    (match reputation-data
      rep-data (get base-reputation rep-data)
      (match profile-data
        prof-data (get reputation-score prof-data)
        u50)))) ;; default score

(define-private (update-system-trust-score)
  (let (
    (credential-count (var-get total-credentials))
    (verified-credentials u0) ;; Simplified - would count verified credentials
    (calculated-score (if (> credential-count u0) (+ u50 (/ (* verified-credentials u50) credential-count)) u90))
  )
    (var-set system-trust-score 
      (if (> calculated-score u100) u100 calculated-score))))

(define-private (validate-assessment-score (score uint))
  (and (>= score u0) (<= score u100)))

(define-private (generate-credential-expiry (issue-date uint))
  (+ issue-date (* CREDENTIAL-VALIDITY-YEARS u52560))) ;; 3 years in blocks

;; Public Functions

;; Credential Issuance Functions

(define-public (issue-skill-credential (holder principal)
                                       (skill-category (string-ascii 30))
                                       (skill-name (string-ascii 50))
                                       (competency-level uint)
                                       (assessment-score uint)
                                       (issuing-experts (list 3 principal))
                                       (credential-type (string-ascii 20)))
  (let (
    (credential-id (var-get next-credential-id))
    (credential-hash (calculate-credential-hash holder skill-name assessment-score))
    (expiry-date (generate-credential-expiry stacks-block-height))
  )
    (asserts! (< (var-get total-credentials) MAX-CREDENTIALS) ERR-INSUFFICIENT-PRIVILEGES)
    (asserts! (is-credential-issuer tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (validate-competency-level competency-level) ERR-INVALID-SCORE)
    (asserts! (validate-assessment-score assessment-score) ERR-INVALID-SCORE)
    (asserts! (> (len issuing-experts) u0) ERR-INVALID-STATUS)
    
    (map-set digital-credentials
      { credential-id: credential-id }
      {
        holder: holder,
        skill-category: skill-category,
        skill-name: skill-name,
        competency-level: competency-level,
        assessment-score: assessment-score,
        issuing-experts: issuing-experts,
        issue-date: stacks-block-height,
        expiry-date: expiry-date,
        credential-hash: credential-hash,
        verification-count: u0,
        active-status: true,
        credential-type: credential-type,
        metadata: ""
      })
    
    ;; Update holder's profile if exists
    (match (update-professional-profile holder credential-id)
      success-result (begin
        (var-set next-credential-id (+ credential-id u1))
        (var-set total-credentials (+ (var-get total-credentials) u1))
        (ok credential-id))
      error-result (begin
        (var-set next-credential-id (+ credential-id u1))
        (var-set total-credentials (+ (var-get total-credentials) u1))
        (ok credential-id)))))

(define-public (update-credential-status (credential-id uint) (active bool))
  (let (
    (credential (unwrap! (map-get? digital-credentials { credential-id: credential-id }) ERR-CREDENTIAL-NOT-FOUND))
  )
    (asserts! (or 
      (is-eq tx-sender (get holder credential))
      (is-credential-issuer tx-sender)) ERR-NOT-AUTHORIZED)
    
    (map-set digital-credentials
      { credential-id: credential-id }
      (merge credential { active-status: active }))
    
    (ok true)))

;; Professional Profile Management

(define-public (create-professional-profile (name (string-ascii 50))
                                            (primary-skills (list 10 (string-ascii 30)))
                                            (career-level (string-ascii 20)))
  (let (
    (profile-id tx-sender)
    (existing-profile (map-get? professional-profiles { profile-id: profile-id }))
  )
    (asserts! (is-none existing-profile) ERR-ALREADY-EXISTS)
    
    (map-set professional-profiles
      { profile-id: profile-id }
      {
        name: name,
        credentials: (list),
        reputation-score: u50, ;; starting reputation
        total-verifications: u0,
        career-level: career-level,
        primary-skills: primary-skills,
        profile-created: stacks-block-height,
        last-updated: stacks-block-height,
        verification-history: (list),
        endorsements: (list)
      })
    
    (ok profile-id)))

(define-public (update-professional-profile (profile-id principal) (credential-id uint))
  (let (
    (profile (unwrap! (map-get? professional-profiles { profile-id: profile-id }) ERR-CREDENTIAL-NOT-FOUND))
    (current-credentials (get credentials profile))
  )
    (asserts! (or (is-eq tx-sender profile-id) (is-credential-issuer tx-sender)) ERR-NOT-AUTHORIZED)
    
    (map-set professional-profiles
      { profile-id: profile-id }
      (merge profile 
        {
          credentials: (unwrap! (as-max-len? (append current-credentials credential-id) u20) ERR-INSUFFICIENT-PRIVILEGES),
          last-updated: stacks-block-height
        }))
    
    (ok true)))

;; Employer Verification Functions

(define-public (verify-credential (credential-id uint)
                                 (verification-purpose (string-ascii 50))
                                 (additional-checks (list 3 (string-ascii 30))))
  (let (
    (verification-id (var-get next-verification-id))
    (credential (unwrap! (map-get? digital-credentials { credential-id: credential-id }) ERR-CREDENTIAL-NOT-FOUND))
    (credential-valid (is-credential-valid credential-id))
    (confidence-score (if credential-valid u95 u20))
  )
    (asserts! (is-verified-employer tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! credential-valid ERR-EXPIRED-CREDENTIAL)
    
    (map-set employer-verifications
      { verification-id: verification-id }
      {
        employer: tx-sender,
        credential-id: credential-id,
        candidate: (get holder credential),
        verification-purpose: verification-purpose,
        verification-date: stacks-block-height,
        verification-result: credential-valid,
        confidence-score: confidence-score,
        additional-checks: additional-checks,
        verification-notes: "",
        follow-up-required: false
      })
    
    ;; Update credential verification count
    (map-set digital-credentials
      { credential-id: credential-id }
      (merge credential 
        { verification-count: (+ (get verification-count credential) u1) }))
    
    (var-set next-verification-id (+ verification-id u1))
    (ok verification-id)))

(define-public (register-employer (company-name (string-ascii 50))
                                 (integration-type (string-ascii 20))
                                 (subscription-tier (string-ascii 20)))
  (let (
    (employer-id tx-sender)
    (existing-integration (map-get? employer-integrations { employer-id: employer-id }))
  )
    (asserts! (is-none existing-integration) ERR-ALREADY-EXISTS)
    
    (map-set employer-integrations
      { employer-id: employer-id }
      {
        company-name: company-name,
        integration-type: integration-type,
        api-access-level: u3, ;; default access level
        verification-preferences: (list),
        auto-verification-enabled: false,
        integration-date: stacks-block-height,
        usage-statistics: (list),
        subscription-tier: subscription-tier
      })
    
    ;; Add to verified employers list
    (let (
      (current-employers (var-get verified-employers))
    )
      (var-set verified-employers 
        (unwrap! (as-max-len? (append current-employers employer-id) u100) ERR-INSUFFICIENT-PRIVILEGES)))
    
    (ok employer-id)))

;; Reputation and Career Tracking

(define-public (update-reputation-score (user principal) (new-score uint) (score-factors (list 5 uint)))
  (let (
    (existing-reputation (map-get? reputation-records { user-id: user }))
  )
    (asserts! (is-reputation-validator tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (validate-assessment-score new-score) ERR-INVALID-SCORE)
    
    (map-set reputation-records
      { user-id: user }
      {
        base-reputation: new-score,
        skill-endorsements: (list),
        peer-ratings: (list),
        employer-feedback: (list),
        community-contributions: u0,
        reputation-factors: score-factors,
        last-reputation-update: stacks-block-height,
        reputation-trend: "stable"
      })
    
    ;; Update professional profile reputation
    (let (
      (profile (map-get? professional-profiles { profile-id: user }))
    )
      (match profile
        profile-data 
          (map-set professional-profiles
            { profile-id: user }
            (merge profile-data { reputation-score: new-score }))
        false))
    
    (ok true)))

(define-public (record-career-progression (professional principal)
                                         (skill-category (string-ascii 30))
                                         (milestones (list 10 uint))
                                         (trajectory (string-ascii 20)))
  (let (
    (progression-id (var-get next-progression-id))
  )
    (asserts! (or (is-eq tx-sender professional) (is-credential-issuer tx-sender)) ERR-NOT-AUTHORIZED)
    
    (map-set career-progressions
      { progression-id: progression-id }
      {
        professional: professional,
        skill-category: skill-category,
        progression-milestones: milestones,
        competency-improvements: (list),
        certification-timeline: (list),
        career-trajectory: trajectory,
        growth-metrics: (list),
        next-skill-recommendations: (list)
      })
    
    (var-set next-progression-id (+ progression-id u1))
    (ok progression-id)))

;; Read-only Functions

(define-read-only (get-credential-details (credential-id uint))
  (map-get? digital-credentials { credential-id: credential-id }))

(define-read-only (get-professional-profile (profile-id principal))
  (map-get? professional-profiles { profile-id: profile-id }))

(define-read-only (get-verification-record (verification-id uint))
  (map-get? employer-verifications { verification-id: verification-id }))

(define-read-only (get-reputation-data (user principal))
  (map-get? reputation-records { user-id: user }))

(define-read-only (verify-credential-authenticity (credential-id uint))
  (let (
    (credential (map-get? digital-credentials { credential-id: credential-id }))
  )
    (match credential
      credential-data {
        valid: (is-credential-valid credential-id),
        holder: (get holder credential-data),
        issue-date: (get issue-date credential-data),
        verification-count: (get verification-count credential-data)
      }
      { valid: false, holder: tx-sender, issue-date: u0, verification-count: u0 })))

(define-read-only (get-system-stats)
  {
    total-credentials: (var-get total-credentials),
    total-verifications: (- (var-get next-verification-id) u1),
    total-progressions: (- (var-get next-progression-id) u1),
    system-trust-score: (var-get system-trust-score)
  })

(define-read-only (is-user-issuer (user principal))
  (is-credential-issuer user))

(define-read-only (is-employer-verified (employer principal))
  (is-verified-employer employer))

