# UniBuzz Integration Execution Board

Last updated: 2026-03-16
Program owner: Product + Backend + Mobile
Reference roadmap: `docs/system_integration_phases.md`

## How To Use This Board
- Update `Status` daily.
- Keep `ETA` realistic (date or sprint/week).
- Do not mark `Done` unless validation evidence exists.
- Add blocker notes in the `Blockers` section with owner and next action.

## Status Legend
| Status | Meaning |
|---|---|
| Not Started | Work has not begun |
| In Progress | Work is active |
| Blocked | Work is blocked by dependency |
| In Review | Implementation done, awaiting QA/review |
| Done | Accepted and validated |

## Priority Legend
| Priority | Meaning |
|---|---|
| P0 | Critical path to MVP completion |
| P1 | Important, can proceed in parallel |
| P2 | Nice-to-have within phase |

## Master Execution Table
| ID | Phase | Priority | Task | Dependency | Owner | ETA | Status | Validation Evidence |
|---|---|---|---|---|---|---|---|---|
| P0-01 | Phase 0 | P0 | Freeze `GET /api/feed` schema (including author identity fields decision) | Backend alignment | Backend | Week 1 | Not Started | Contract doc version + sample payload |
| P0-02 | Phase 0 | P0 | Confirm `/auth/refresh` availability and deployed behavior | Environment parity | Backend | Week 1 | Not Started | Staging + prod curl report |
| P0-03 | Phase 0 | P0 | Standardize API error format (`message|error|detail|errors` policy) | API governance | Backend | Week 1 | Not Started | Error contract appendix |
| P0-04 | Phase 0 | P1 | Publish Postman/HTTP collection for all Phase 1-4 endpoints | Endpoint docs | Backend | Week 1 | Not Started | Shared collection + examples |
| P0-05 | Phase 0 | P1 | Align service parsing rules with finalized schemas | P0-01, P0-03 | Mobile | Week 1 | Not Started | PR + tests |
| P1-01 | Phase 1 | P0 | Add service-layer tests for auth/session/error parsing | P0-03 | Mobile | Week 2 | Done | `test/services/auth_service_test.dart` + `test/services/video_service_test.dart`; `flutter test` (16 passed), `flutter analyze` clean |
| P1-02 | Phase 1 | P0 | Add widget tests for feed/report failure states and 401 UX | P1-01 | Mobile | Week 2 | Done | `test/interfaces/feed_report_failure_test.dart`; `flutter test` (20 passed), `flutter analyze` clean |
| P1-03 | Phase 1 | P0 | Add CI gate (`flutter analyze`, `flutter test`) | Repo permissions | Mobile | Week 2 | Not Started | CI workflow run |
| P1-04 | Phase 1 | P1 | Review snackbar and error copy consistency | Product review | Product + Mobile | Week 2 | Not Started | UX review notes |
| P1-05 | Phase 1 | P1 | Regression pass: vote/comment/report across feed/fullscreen | P1-02 | QA + Mobile | Week 2 | Not Started | QA checklist |
| P2-01 | Phase 2 | P0 | Implement backend path for author identity data (enriched feed or user lookup endpoint) | P0-01 | Backend | Week 3 | Not Started | Contract + endpoint response |
| P2-02 | Phase 2 | P0 | Update feed mapping to consume actual author fields and remove synthetic fallback display for valid users | P2-01 | Mobile | Week 3 | In Progress | Nested payload-aware author/profile mapping in `lib/interfaces/feed_screen.dart`; awaiting final backend schema freeze |
| P2-03 | Phase 2 | P0 | Bind fullscreen author/hashtags to backend-fed data model | P2-01 | Mobile | Week 3 | In Progress | Fullscreen metadata now bound to live payload in `lib/interfaces/full_screen_view.dart`; awaiting backend schema freeze |
| P2-04 | Phase 2 | P1 | Add caching strategy for identity lookups (if lookup endpoint path chosen) | P2-01 | Mobile | Week 3 | Not Started | Perf profile + code review |
| P2-05 | Phase 2 | P1 | Data parity QA matrix (feed vs fullscreen identity consistency) | P2-02, P2-03 | QA | Week 3 | Not Started | Signed QA matrix |
| P3-01 | Phase 3 | P0 | Confirm `GET /api/search` contract and pagination behavior | Backend docs | Backend | Week 4 | Not Started | Contract update |
| P3-02 | Phase 3 | P0 | Replace Discover placeholder tags with backend-driven data | P3-01 | Mobile | Week 4 | In Progress | `lib/interfaces/discover_screen.dart` now queries `VideoService.searchVideos` and renders live backend result cards with fullscreen navigation |
| P3-03 | Phase 3 | P0 | Implement debounced search input + loading/empty/error states | P3-01 | Mobile | Week 4 | In Progress | Debounced query handling + explicit loading/empty/error/retry states implemented in Discover UI |
| P3-04 | Phase 3 | P1 | Implement results navigation to fullscreen/feed detail | P3-03 | Mobile | Week 4 | Not Started | Navigation tests |
| P3-05 | Phase 3 | P1 | Discover performance pass under slow network conditions | P3-03 | QA + Mobile | Week 4 | Not Started | Throttled test report |
| P4-01 | Phase 4 | P0 | Implement real media upload path to Cloudinary (or backend proxy) | Infra decision | Backend + Mobile | Week 5 | Not Started | Upload e2e trace |
| P4-02 | Phase 4 | P0 | Replace simulated publish flow with `POST /api/videos/upload` integration | P4-01 | Mobile | Week 5 | In Progress | `lib/interfaces/publish_screen.dart` now calls `VideoService.uploadVideo` with caption/tags + resolved `input_url` |
| P4-03 | Phase 4 | P0 | Implement status polling with resilient retry/timeout UX | P4-02 | Mobile | Week 5 | In Progress | Publish flow now polls `VideoService.getVideoStatus` with progress/status messaging and timeout handling |
| P4-04 | Phase 4 | P1 | Add failure recovery path (retry, cancel, draft retention policy) | P4-03 | Product + Mobile | Week 5 | Not Started | UX acceptance |
| P4-05 | Phase 4 | P1 | Validate post visibility in feed after processing completion | P4-03 | QA + Backend | Week 5 | Not Started | End-to-end QA run |
| P5-01 | Phase 5 | P0 | Finalize non-admin profile endpoint (`/api/me` or equivalent) | Backend scope | Backend | Week 6 | Not Started | Endpoint contract |
| P5-02 | Phase 5 | P0 | Wire `profile_screen.dart` to live profile data | P5-01 | Mobile | Week 6 | In Progress | `lib/interfaces/profile_screen.dart` now loads profile dynamically via `AuthService.getCurrentUserProfile()` with refresh/loading/error UI; `AuthService` probes likely `/me` endpoints and falls back to JWT claims |
| P5-03 | Phase 5 | P0 | Finalize endpoint for current user's posts list | Backend scope | Backend | Week 6 | Not Started | Endpoint contract |
| P5-04 | Phase 5 | P0 | Wire `my_posts_screen.dart` to backend list + refresh | P5-03 | Mobile | Week 6 | In Progress | `lib/interfaces/my_posts_screen.dart` now loads live posts from `VideoService.fetchFeed`, filters by current user, supports refresh/loading/error states, and resolves per-post vote/comment metrics |
| P5-05 | Phase 5 | P1 | Implement creator edit/delete post flows if backend supports write endpoints | P5-03 | Backend + Mobile | Week 6 | Not Started | CRUD tests |
| P5-06 | Phase 5 | P2 | Retire or wire `create_account_screen.dart` to signup path | Product decision | Mobile | Week 6 | Not Started | Navigation QA |
| P6-01 | Phase 6 | P0 | Define moderation operations surface (admin app vs ops tooling) | Product decision | Product + Backend | Week 7 | Not Started | Decision record |
| P6-02 | Phase 6 | P0 | Integrate report queue + triage actions in chosen moderation surface | P6-01 | Backend + Mobile/Admin | Week 7 | Not Started | Moderation e2e |
| P6-03 | Phase 6 | P1 | Add moderation audit logging and action traceability | P6-02 | Backend | Week 7 | Not Started | Audit sample report |
| P7-01 | Phase 7 | P0 | Instrument crash and error monitoring | Infra + keys | Mobile | Week 8 | Not Started | Monitoring dashboard |
| P7-02 | Phase 7 | P0 | Build release checklist and rollback playbook | Team process | Product + Mobile + Backend | Week 8 | Not Started | Signed checklist |
| P7-03 | Phase 7 | P0 | Pilot rollout with error-budget criteria | P7-01, P7-02 | Product + QA | Week 8 | Not Started | Pilot report |
| P7-04 | Phase 7 | P1 | Performance benchmark and optimization pass | P4-05, P5-04 | Mobile + QA | Week 8 | Not Started | Perf test report |

## Current Sprint Focus (Suggested)
| Focus Item | Why It Matters | Owner | Status |
|---|---|---|---|
| P0-01 feed schema freeze | Unblocks identity parity and removes frontend guesswork | Backend | Not Started |
| P0-02 refresh endpoint decision | Unblocks final auth strategy and session UX | Backend | Not Started |
| P1-01 service-level tests | Stabilizes current integrated paths | Mobile | Done |
| P1-02 widget failure/401 UX tests | Validates user-facing resilience and session-expired feedback | Mobile | Done |
| P2-02/P2-03 metadata parity wiring | Keeps integration moving while backend contract finalizes | Mobile | In Progress |
| P3-02/P3-03 discover search wiring | Activates backend discovery path and result UX scaffolding | Mobile | In Progress |
| P4-02/P4-03 publish backend wiring | Replaces simulated upload with real queue + processing loop | Mobile | In Progress |
| P1-03 CI gate | Prevents regressions in every phase | Mobile | Not Started |

## Blockers Log
| Date | Blocker | Impacted IDs | Owner | Next Action | Target Resolution |
|---|---|---|---|---|---|
|  |  |  |  |  |  |

## Decision Log
| Date | Decision | Rationale | Owner |
|---|---|---|---|
|  |  |  |  |

## Weekly Update Template
Use this template during standup or weekly review.

### Week Of
- Date:
- Sprint/Iteration:

### Completed
- IDs:
- Notes:

### In Progress
- IDs:
- Notes:

### Blocked
- IDs:
- Blocker details:
- Unblock owner:

### Next Week Plan
- IDs:
- Goals:

## Definition of Done (Per Task)
A task is `Done` only if all are true:
- Code implemented and merged.
- Loading, empty, and error states handled.
- Tests added or updated and passing.
- Analyzer passes.
- Relevant docs updated (`Integration.md` or `docs/*.md`).
- QA evidence linked in `Validation Evidence`.
