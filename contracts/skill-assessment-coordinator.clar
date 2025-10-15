;; Skill Assessment Coordinator Smart Contract
;; Coordinates peer-to-peer skill assessments, matches candidates with industry experts,
;; manages practical evaluations, verifies assessment quality, and maintains certification standards

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-EXPERT-NOT-FOUND (err u2))
(define-constant ERR-ASSESSMENT-NOT-FOUND (err u3))
(define-constant ERR-CANDIDATE-NOT-FOUND (err u4))
(define-constant ERR-INVALID-STATUS (err u5))
(define-constant ERR-ALREADY-EXISTS (err u6))
(define-constant ERR-INVALID-SCORE (err u7))
(define-constant ERR-INSUFFICIENT-PRIVILEGES (err u8))
(define-constant ERR-ASSESSMENT-EXPIRED (err u9))
(define-constant ERR-INVALID-SKILL-LEVEL (err u10))

(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-EXPERTS u500)
(define-constant MAX-ASSESSMENTS u1000)
(define-constant MIN-EXPERT-EXPERIENCE u2) ;; 2 years minimum
(define-constant MAX-ASSESSMENT-DURATION u14400) ;; 4 hours in minutes
(define-constant PASSING-SCORE u70) ;; 70% to pass

;; Data Maps and Variables

;; Expert management
(define-map skill-experts
  { expert-id: principal }
  {
    name: (string-ascii 50),
    skill-domains: (list 10 (string-ascii 30)),
    experience-years: uint,
    certifications: (list 5 (string-ascii 50)),
    expertise-level: uint, ;; 1-5 scale
    assessment-count: uint,
    average-rating: uint,
    active-status: bool,
    joined-at: uint,
    specializations: (list 5 (string-ascii 40))
  })

;; Assessment creation and management
(define-map skill-assessments
  { assessment-id: uint }
  {
    creator: principal,
    skill-category: (string-ascii 30),
    skill-subcategory: (string-ascii 40),
    difficulty-level: uint, ;; 1-5 scale
    assessment-type: (string-ascii 20), ;; practical, theoretical, project-based
    evaluation-criteria: (list 5 (string-ascii 60)),
    time-limit: uint, ;; in minutes
    max-candidates: uint,
    created-at: uint,
    expires-at: uint,
    status: (string-ascii 20), ;; active, paused, completed, cancelled
    required-expert-count: uint
  })

;; Candidate assessment tracking
(define-map assessment-candidates
  { assessment-id: uint, candidate-id: principal }
  {
    application-date: uint,
    assigned-experts: (list 3 principal),
    assessment-status: (string-ascii 20), ;; registered, in-progress, completed, failed
    start-time: (optional uint),
    completion-time: (optional uint),
    preliminary-score: (optional uint),
    expert-evaluations: (list 3 uint),
    feedback-received: (list 3 (string-ascii 200)),
    final-score: (optional uint),
    certification-earned: bool
  })

;; Expert evaluation records
(define-map expert-evaluations
  { evaluation-id: uint }
  {
    expert: principal,
    assessment-id: uint,
    candidate: principal,
    evaluation-criteria: (list 5 uint), ;; scores for each criterion
    overall-score: uint,
    detailed-feedback: (string-ascii 300),
    evaluation-time: uint,
    confidence-level: uint, ;; expert's confidence in assessment
    recommendation: (string-ascii 20), ;; pass, fail, retry
    quality-verified: bool
  })

;; Assessment quality control
(define-map quality-reviews
  { review-id: uint }
  {
    reviewer: principal,
    evaluation-id: uint,
    review-score: uint, ;; quality score of the evaluation
    review-comments: (string-ascii 200),
    review-date: uint,
    approved: bool,
    improvement-suggestions: (list 3 (string-ascii 50))
  })

;; Skill competency tracking
(define-map skill-competencies
  { skill-id: (string-ascii 30) }
  {
    skill-name: (string-ascii 50),
    skill-description: (string-ascii 150),
    competency-levels: (list 5 (string-ascii 30)), ;; beginner to expert
    assessment-standards: (list 5 (string-ascii 100)),
    industry-demand: uint, ;; 1-10 scale
    last-updated: uint,
    verified-experts: (list 20 principal)
  })

;; Counter variables
(define-data-var next-assessment-id uint u1)
(define-data-var next-evaluation-id uint u1)
(define-data-var next-review-id uint u1)
(define-data-var total-experts uint u0)
(define-data-var platform-quality-score uint u85) ;; out of 100

;; Authorization and governance
(define-data-var platform-admins (list 5 principal) (list CONTRACT-OWNER))
(define-data-var quality-reviewers (list 10 principal) (list))
(define-data-var skill-validators (list 15 principal) (list CONTRACT-OWNER))

;; Private Functions

(define-private (is-platform-admin (user principal))
  (is-some (index-of (var-get platform-admins) user)))

(define-private (is-quality-reviewer (user principal))
  (is-some (index-of (var-get quality-reviewers) user)))

(define-private (is-skill-validator (user principal))
  (is-some (index-of (var-get skill-validators) user)))

(define-private (is-expert-registered (expert principal))
  (is-some (map-get? skill-experts { expert-id: expert })))

(define-private (calculate-expert-rating (expert principal))
  (let (
    (expert-data (unwrap! (map-get? skill-experts { expert-id: expert }) u0))
    (assessment-count (get assessment-count expert-data))
    (current-rating (get average-rating expert-data))
  )
    (if (> assessment-count u0)
      current-rating
      u50))) ;; default rating for new experts

(define-private (validate-assessment-criteria (criteria (list 5 (string-ascii 60))))
  (and (> (len criteria) u0) (<= (len criteria) u5)))

(define-private (calculate-final-score (scores (list 3 uint)))
  (let (
    (total-scores (fold + scores u0))
    (score-count (len scores))
  )
    (if (> score-count u0)
      (/ total-scores score-count)
      u0)))

(define-private (validate-skill-level (level uint))
  (and (>= level u1) (<= level u5)))

(define-private (is-assessment-active (assessment-id uint))
  (let (
    (assessment (map-get? skill-assessments { assessment-id: assessment-id }))
  )
    (match assessment
      assessment-data (and 
        (is-eq (get status assessment-data) "active")
        (> (get expires-at assessment-data) stacks-block-height))
      false)))

(define-private (update-platform-quality-score)
  (let (
    (total-evaluations (var-get next-evaluation-id))
    (approved-evaluations u0) ;; Simplified - would count approved evaluations
    (calculated-score (if (> total-evaluations u0) (+ u50 (/ (* approved-evaluations u50) total-evaluations)) u85))
  )
    (var-set platform-quality-score 
      (if (> calculated-score u100) u100 calculated-score))))

;; Public Functions

;; Expert Management Functions

(define-public (register-expert (name (string-ascii 50))
                                (skill-domains (list 10 (string-ascii 30)))
                                (experience-years uint)
                                (certifications (list 5 (string-ascii 50)))
                                (expertise-level uint))
  (let (
    (expert-id tx-sender)
  )
    (asserts! (< (var-get total-experts) MAX-EXPERTS) ERR-INSUFFICIENT-PRIVILEGES)
    (asserts! (is-none (map-get? skill-experts { expert-id: expert-id })) ERR-ALREADY-EXISTS)
    (asserts! (>= experience-years MIN-EXPERT-EXPERIENCE) ERR-INSUFFICIENT-PRIVILEGES)
    (asserts! (validate-skill-level expertise-level) ERR-INVALID-SKILL-LEVEL)
    (asserts! (> (len skill-domains) u0) ERR-INVALID-STATUS)
    
    (map-set skill-experts
      { expert-id: expert-id }
      {
        name: name,
        skill-domains: skill-domains,
        experience-years: experience-years,
        certifications: certifications,
        expertise-level: expertise-level,
        assessment-count: u0,
        average-rating: u50, ;; starting rating
        active-status: true,
        joined-at: stacks-block-height,
        specializations: (list)
      })
    
    (var-set total-experts (+ (var-get total-experts) u1))
    (ok expert-id)))

(define-public (update-expert-status (expert principal) (active bool))
  (let (
    (expert-data (unwrap! (map-get? skill-experts { expert-id: expert }) ERR-EXPERT-NOT-FOUND))
  )
    (asserts! (or (is-eq tx-sender expert) (is-platform-admin tx-sender)) ERR-NOT-AUTHORIZED)
    
    (map-set skill-experts
      { expert-id: expert }
      (merge expert-data { active-status: active }))
    
    (ok true)))

;; Assessment Creation and Management

(define-public (create-skill-assessment (skill-category (string-ascii 30))
                                        (skill-subcategory (string-ascii 40))
                                        (difficulty-level uint)
                                        (assessment-type (string-ascii 20))
                                        (evaluation-criteria (list 5 (string-ascii 60)))
                                        (time-limit uint)
                                        (max-candidates uint)
                                        (duration-blocks uint))
  (let (
    (assessment-id (var-get next-assessment-id))
    (expires-at (+ stacks-block-height duration-blocks))
  )
    (asserts! (is-expert-registered tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (validate-skill-level difficulty-level) ERR-INVALID-SKILL-LEVEL)
    (asserts! (validate-assessment-criteria evaluation-criteria) ERR-INVALID-STATUS)
    (asserts! (and (> time-limit u0) (<= time-limit MAX-ASSESSMENT-DURATION)) ERR-INVALID-STATUS)
    (asserts! (> max-candidates u0) ERR-INVALID-STATUS)
    
    (map-set skill-assessments
      { assessment-id: assessment-id }
      {
        creator: tx-sender,
        skill-category: skill-category,
        skill-subcategory: skill-subcategory,
        difficulty-level: difficulty-level,
        assessment-type: assessment-type,
        evaluation-criteria: evaluation-criteria,
        time-limit: time-limit,
        max-candidates: max-candidates,
        created-at: stacks-block-height,
        expires-at: expires-at,
        status: "active",
        required-expert-count: (if (>= difficulty-level u4) u3 u2)
      })
    
    (var-set next-assessment-id (+ assessment-id u1))
    (ok assessment-id)))

(define-public (register-for-assessment (assessment-id uint))
  (let (
    (assessment (unwrap! (map-get? skill-assessments { assessment-id: assessment-id }) ERR-ASSESSMENT-NOT-FOUND))
    (existing-registration (map-get? assessment-candidates { assessment-id: assessment-id, candidate-id: tx-sender }))
  )
    (asserts! (is-none existing-registration) ERR-ALREADY-EXISTS)
    (asserts! (is-assessment-active assessment-id) ERR-ASSESSMENT-EXPIRED)
    
    (map-set assessment-candidates
      { assessment-id: assessment-id, candidate-id: tx-sender }
      {
        application-date: stacks-block-height,
        assigned-experts: (list),
        assessment-status: "registered",
        start-time: none,
        completion-time: none,
        preliminary-score: none,
        expert-evaluations: (list),
        feedback-received: (list),
        final-score: none,
        certification-earned: false
      })
    
    (ok true)))

(define-public (assign-experts-to-candidate (assessment-id uint)
                                            (candidate principal)
                                            (experts (list 3 principal)))
  (let (
    (assessment (unwrap! (map-get? skill-assessments { assessment-id: assessment-id }) ERR-ASSESSMENT-NOT-FOUND))
    (candidate-data (unwrap! (map-get? assessment-candidates { assessment-id: assessment-id, candidate-id: candidate }) ERR-CANDIDATE-NOT-FOUND))
  )
    (asserts! (or (is-eq tx-sender (get creator assessment)) (is-platform-admin tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get assessment-status candidate-data) "registered") ERR-INVALID-STATUS)
    
    ;; Verify all experts are registered and active
    (asserts! (fold verify-expert-active experts true) ERR-EXPERT-NOT-FOUND)
    
    (map-set assessment-candidates
      { assessment-id: assessment-id, candidate-id: candidate }
      (merge candidate-data 
        {
          assigned-experts: experts,
          assessment-status: "in-progress",
          start-time: (some stacks-block-height)
        }))
    
    (ok true)))

;; Expert Evaluation Functions

(define-public (submit-expert-evaluation (assessment-id uint)
                                         (candidate principal)
                                         (evaluation-scores (list 5 uint))
                                         (overall-score uint)
                                         (detailed-feedback (string-ascii 300))
                                         (recommendation (string-ascii 20)))
  (let (
    (evaluation-id (var-get next-evaluation-id))
    (candidate-data (unwrap! (map-get? assessment-candidates { assessment-id: assessment-id, candidate-id: candidate }) ERR-CANDIDATE-NOT-FOUND))
  )
    (asserts! (is-expert-registered tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (index-of (get assigned-experts candidate-data) tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= overall-score u0) (<= overall-score u100)) ERR-INVALID-SCORE)
    (asserts! (is-eq (get assessment-status candidate-data) "in-progress") ERR-INVALID-STATUS)
    
    (map-set expert-evaluations
      { evaluation-id: evaluation-id }
      {
        expert: tx-sender,
        assessment-id: assessment-id,
        candidate: candidate,
        evaluation-criteria: evaluation-scores,
        overall-score: overall-score,
        detailed-feedback: detailed-feedback,
        evaluation-time: stacks-block-height,
        confidence-level: u80, ;; default confidence
        recommendation: recommendation,
        quality-verified: false
      })
    
    ;; Update candidate's evaluation list
    (let (
      (current-evaluations (get expert-evaluations candidate-data))
      (updated-evaluations (unwrap! (as-max-len? (append current-evaluations overall-score) u3) ERR-INSUFFICIENT-PRIVILEGES))
    )
      (map-set assessment-candidates
        { assessment-id: assessment-id, candidate-id: candidate }
        (merge candidate-data { expert-evaluations: updated-evaluations })))
    
    (var-set next-evaluation-id (+ evaluation-id u1))
    (ok evaluation-id)))

(define-public (complete-candidate-assessment (assessment-id uint) (candidate principal))
  (let (
    (candidate-data (unwrap! (map-get? assessment-candidates { assessment-id: assessment-id, candidate-id: candidate }) ERR-CANDIDATE-NOT-FOUND))
    (evaluation-scores (get expert-evaluations candidate-data))
    (final-score (calculate-final-score evaluation-scores))
    (passed (>= final-score PASSING-SCORE))
  )
    (asserts! (or (is-platform-admin tx-sender) (is-quality-reviewer tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get assessment-status candidate-data) "in-progress") ERR-INVALID-STATUS)
    (asserts! (> (len evaluation-scores) u0) ERR-INVALID-STATUS)
    
    (map-set assessment-candidates
      { assessment-id: assessment-id, candidate-id: candidate }
      (merge candidate-data 
        {
          assessment-status: (if passed "completed" "failed"),
          completion-time: (some stacks-block-height),
          final-score: (some final-score),
          certification-earned: passed
        }))
    
    (ok final-score)))

;; Quality Control Functions

(define-public (review-evaluation-quality (evaluation-id uint)
                                          (review-score uint)
                                          (review-comments (string-ascii 200))
                                          (approved bool))
  (let (
    (review-id (var-get next-review-id))
    (evaluation (unwrap! (map-get? expert-evaluations { evaluation-id: evaluation-id }) ERR-ASSESSMENT-NOT-FOUND))
  )
    (asserts! (is-quality-reviewer tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= review-score u0) (<= review-score u100)) ERR-INVALID-SCORE)
    
    (map-set quality-reviews
      { review-id: review-id }
      {
        reviewer: tx-sender,
        evaluation-id: evaluation-id,
        review-score: review-score,
        review-comments: review-comments,
        review-date: stacks-block-height,
        approved: approved,
        improvement-suggestions: (list)
      })
    
    ;; Update evaluation quality status
    (map-set expert-evaluations
      { evaluation-id: evaluation-id }
      (merge evaluation { quality-verified: approved }))
    
    (var-set next-review-id (+ review-id u1))
    (update-platform-quality-score)
    (ok review-id)))

;; Read-only Functions

(define-read-only (get-expert-info (expert principal))
  (map-get? skill-experts { expert-id: expert }))

(define-read-only (get-assessment-details (assessment-id uint))
  (map-get? skill-assessments { assessment-id: assessment-id }))

(define-read-only (get-candidate-progress (assessment-id uint) (candidate principal))
  (map-get? assessment-candidates { assessment-id: assessment-id, candidate-id: candidate }))

(define-read-only (get-evaluation-details (evaluation-id uint))
  (map-get? expert-evaluations { evaluation-id: evaluation-id }))

(define-read-only (get-platform-stats)
  {
    total-experts: (var-get total-experts),
    total-assessments: (- (var-get next-assessment-id) u1),
    total-evaluations: (- (var-get next-evaluation-id) u1),
    quality-score: (var-get platform-quality-score)
  })

(define-read-only (is-user-expert (user principal))
  (is-expert-registered user))

(define-read-only (is-user-admin (user principal))
  (is-platform-admin user))

;; Helper function for expert verification
(define-private (verify-expert-active (expert principal) (acc bool))
  (let (
    (expert-data (map-get? skill-experts { expert-id: expert }))
  )
    (and acc
      (is-some expert-data)
      (get active-status (unwrap-panic expert-data)))))

