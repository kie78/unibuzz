# UniBuzz Full-System Integration Phases

Last updated: 2026-03-16
Owner: Product + Backend + Mobile

## Purpose
This document is the working roadmap for integrating the full UniBuzz system end-to-end.
It defines phase goals, scope, dependencies, acceptance criteria, and test gates.

Use this as the source of truth for:
- What is already integrated.
- What is missing for full production readiness.
- Which backend contracts block frontend completion.
- How each phase is considered complete.

## Current Baseline (Already Working)
The following is implemented in the app today:
- Persistent auth startup gate with JWT validity and expiry check.
- Login, signup, logout token storage/clear flows.
- Feed loading with pull-to-refresh and best-effort pagination.
- Vote and comment operations with optimistic updates and rollback.
- Report flow with backend submit, loading states, and validation.
- Cross-screen interaction state sync (feed card <-> fullscreen view).
- Automated auth persistence tests in `test/widget_test.dart`.

## Known Gaps To Reach Full Integration
- Feed cards cannot consistently show real names because `/api/feed` contract only guarantees `user_id` for uploader identity.
- Fullscreen view still contains hard-coded handle and hashtags.
- Discover screen is placeholder tags and lacks real search/result wiring.
- Publish screen still simulates upload/processing and does not call real upload/status APIs.
- Profile screen now loads dynamic values via auth service with endpoint probing and JWT-claims fallback.
- `CreateAccountScreen` is a placeholder shell.

## Integration Principles
- Contract first: lock payload schemas before frontend wiring.
- No silent fallbacks for required business data.
- Every phase ends with explicit test gates.
- All async flows must show deterministic user feedback.
- Feature completion means: UI wired + error states + loading states + tests + docs updated.

## Phase Overview
| Phase | Name | Target Outcome | Status |
|---|---|---|---|
| 0 | Contract and Environment Alignment | Stable API contracts and env readiness | Pending |
| 1 | Core User Journey Hardening | Auth/feed/engagement are production-stable | In Progress |
| 2 | Identity and Metadata Parity | Real user identity and metadata across feed/fullscreen | Pending |
| 3 | Discovery Integration | Discover/search is fully backend-driven | Pending |
| 4 | Publish Pipeline Integration | Real upload queue and processing status flow | Pending |
| 5 | Account and Creator Surfaces | Profile/My Posts are backend-powered | Pending |
| 6 | Moderation and Admin Integration | Reports triage and moderation lifecycle | Pending |
| 7 | Release Readiness and Observability | Production launch gate with QA and monitoring | Pending |

## Phase 0: Contract and Environment Alignment
### Objective
Eliminate API ambiguity before deeper integration work.

### Scope
- Confirm endpoint availability and auth requirements in deployed environment.
- Publish exact response schemas used by mobile.
- Define contract change process and versioning rules.

### Backend Deliverables
- Lock `GET /api/feed` response shape, including uploader identity fields.
- Confirm whether `/auth/refresh` is available in deployment.
- Confirm access policy for comments and votes read endpoints.
- Document all 4xx and 5xx error payload schemas.

### Mobile Deliverables
- Align service parsing to locked schemas only.
- Remove guesswork mapping for fields not in contract.
- Keep explicit fallback messaging for session expiry.

### Exit Criteria
- API contract document is approved and versioned.
- No unresolved endpoint ambiguity for phases 1-4.
- Staging and production endpoint behavior matches docs.

## Phase 1: Core User Journey Hardening
### Objective
Ensure the main user loop (auth -> feed -> engage -> report) is robust.

### Scope
- Authentication persistence and session handling.
- Feed retrieval and engagement behavior consistency.
- Report submission reliability.

### Done
- Persistent auth checks with expiry guard on startup.
- Token clear on invalid/expired session paths.
- Feed vote/comment/report API integration.
- Basic automated auth persistence tests.
- Service-layer tests for auth/session/error parsing.
- Widget tests for feed/report failure states and 401 session-expired UX.

### Remaining
- Expand automated tests for feed vote/comment/report behaviors.

### Exit Criteria
- Happy path and error path tests pass for auth/feed/engagement.
- No critical P0 bugs in vote/comment/report flows.
- Analyzer and tests pass in CI.

## Phase 2: Identity and Metadata Parity
### Objective
Display accurate backend identity and metadata on all content surfaces.

### Scope
- Feed card author info.
- Fullscreen content metadata parity.
- Hashtag and profile meta consistency.

### Backend Dependencies
- Option A: enrich `/api/feed` items with `username`, `full_name`, and university/year fields.
- Option B: expose non-admin profile lookup endpoint by `user_id`.

### Mobile Deliverables
- Replace feed fallback `User <shortId>` with real names when available.
- Support nested user payload patterns if contract includes nested object.
- Bind fullscreen handle and hashtags to the same model used by feed cards.

### Current Progress
- Feed and fullscreen now read author/profile/tag metadata from multiple payload shapes (including nested user/author/uploader objects).
- Fullscreen no longer uses hard-coded handle/hashtags; it now uses payload-driven values with graceful fallback.
- Final parity still depends on backend schema freeze for guaranteed identity fields.

### Exit Criteria
- Feed and fullscreen show same author identity for each video.
- No hard-coded handles/hashtags remain in content views.
- Data mismatch rate is zero in QA dataset.

## Phase 3: Discovery Integration
### Objective
Turn Discover into a real search surface.

### Scope
- Search by hashtag and username.
- Real result rendering and navigation.

### Backend Dependencies
- `GET /api/search` supports expected query patterns and pagination if needed.

### Mobile Deliverables
- Replace placeholder tags in `discover_screen.dart`.
- Debounced search input with loading/empty/error states.
- Result cards route to fullscreen/feed detail consistently.

### Current Progress
- `discover_screen.dart` now calls `VideoService.searchVideos` for hashtag and username lookup paths.
- Debounced query handling and explicit loading, empty, error, and retry UI states are now implemented.
- Search results render as live backend cards and open `FullScreenVideoView` for detail playback.

### Exit Criteria
- Discover uses only backend data.
- Search returns deterministic results for test fixtures.
- Empty and no-match states are UX-complete.

## Phase 4: Publish Pipeline Integration
### Objective
Replace simulated post publishing with real upload and processing lifecycle.

### Scope
- Upload source media.
- Queue processing via backend.
- Poll status and resolve completion/failure.

### Backend Dependencies
- `POST /api/videos/upload` operational with clear response contract.
- `GET /api/videos/:video_id/status` stable transitions (`pending`, `complete`, `failed`).

### Mobile Deliverables
- Replace simulated timers in `publish_screen.dart`.
- Integrate Cloudinary upload (or backend proxy) for `input_url`.
- Real progress and status updates with retry path.

### Current Progress
- `publish_screen.dart` now uses real `VideoService.uploadVideo` enqueue calls instead of simulated timers.
- Processing status is now polled via `VideoService.getVideoStatus` with in-UI progress/status updates and timeout protection.
- Local-file source handling supports either optional public URL override or unsigned Cloudinary upload via dart defines.

### Exit Criteria
- A captured/trimmed video can be published end-to-end.
- Failure paths are recoverable and clearly communicated.
- New post appears in feed after processing complete.

## Phase 5: Account and Creator Surfaces
### Objective
Integrate user-centric screens with live backend data.

### Scope
- Profile details.
- My Posts listing and actions.
- Create account shell cleanup.

### Backend Dependencies
- Non-admin endpoint for current user profile (`/api/me` or equivalent).
- Endpoint for current user posts.
- If supported: post update/delete endpoints.

### Mobile Deliverables
- Replace static values in `profile_screen.dart`.
- Replace local `_posts` in `my_posts_screen.dart` with live data.
- Wire create account screen to signup flow or retire it.

### Current Progress
- `my_posts_screen.dart` now loads backend feed data, filters posts by current authenticated user ID, supports pull-to-refresh/loading/error states, and loads per-post vote/comment metrics.
- `profile_screen.dart` now loads dynamic profile fields through `AuthService.getCurrentUserProfile()` with loading/error/refresh UX and graceful fallback to JWT claims when profile endpoints are unavailable.
- Final profile parity still depends on a guaranteed non-admin profile endpoint (`/api/me` or equivalent) for complete server-truth fields.

### Exit Criteria
- Profile and My Posts show server truth.
- Creator actions reflect server state after operation.
- No placeholder account screens remain.

## Phase 6: Moderation and Admin Integration
### Objective
Close the moderation loop from report submit to admin action.

### Scope
- Report lifecycle.
- Admin moderation controls.
- User moderation statuses.

### Backend Dependencies
- Stable admin endpoints in `Integration.md`.
- Role enforcement and auditable moderation actions.

### Mobile/Admin Deliverables
- If admin app exists: report queue, triage, resolve, remove content.
- If no admin app: define near-term moderation operations process.

### Exit Criteria
- Report can be submitted, reviewed, and resolved.
- Moderation actions are visible and traceable.

## Phase 7: Release Readiness and Observability
### Objective
Ship safely with confidence in reliability and monitoring.

### Scope
- QA, performance, security checks, and rollback strategy.

### Deliverables
- CI gates for `flutter analyze` and tests.
- Integration test suite for critical user journeys.
- Crash and error monitoring instrumentation.
- Release checklist and rollback playbook.

### Exit Criteria
- Launch checklist complete and signed.
- Error budgets and monitoring dashboards ready.
- Pilot rollout succeeds with no P0 regression.

## Cross-Phase Test Strategy
### Required Test Layers
- Unit tests for service parsing and auth/session logic.
- Widget tests for startup auth gating and key screen state transitions.
- Integration tests for login -> feed -> engage -> report -> logout.

### Minimum Regression Pack (Run Every Phase)
- Auth startup route decision.
- Feed load and pagination fallback behavior.
- Vote and comment counter sync after screen navigation.
- Report submit success/failure handling.
- Session-expired messaging and forced re-auth.

## Risks and Mitigations
| Risk | Impact | Mitigation |
|---|---|---|
| Backend docs differ from deployed behavior | Delays and unstable UX | Phase 0 contract freeze and staging verification |
| Missing user identity fields in feed | Incomplete UX in Phase 2 | Add explicit backend dependency and fallback policy |
| Upload pipeline complexity | Delivery slip in Phase 4 | Deliver in slices: upload first, status polling second |
| Insufficient automated tests | Regressions across phases | Enforce CI gates before each phase close |

## Phase Tracking Template
Use this table to track execution sprint by sprint.

| Item | Owner | Status | Notes |
|---|---|---|---|
| Phase 0 contract freeze |  |  |  |
| Phase 1 hardening complete |  |  |  |
| Phase 2 identity parity complete |  |  |  |
| Phase 3 discovery live |  |  |  |
| Phase 4 publish pipeline live |  |  |  |
| Phase 5 account/creator live |  |  |  |
| Phase 6 moderation loop live |  |  |  |
| Phase 7 release gate approved |  |  |  |

## Immediate Next Actions
- Assign owners for Phase 0 and Phase 2 backend dependency items.
- Decide if identity data comes from enriched feed payload or user lookup endpoint.
- Start implementing Phase 1 remaining tests while contract work proceeds.
