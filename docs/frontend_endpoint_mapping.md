## Frontend screens → API endpoints

This document maps existing Flutter screens in `lib/interfaces/` to the UniBuzz API endpoints described in `Integration.md`. It is a guide for replacing demo data and local-only flows with real backend integration.

### Auth & account

- `login_screen.dart`
  - Uses `AuthService.login` → `POST /auth/login`
  - Future:
    - Handle auth errors surfaced from the API (already partially done via exception messages).
    - Optionally respond to global logout/401 flows triggered elsewhere.

- `signup_screen.dart`
  - Uses `AuthService.register` → `POST /auth/register`
  - Future:
    - Decide whether to auto-login (call `POST /auth/login` after a successful registration) or have the backend return tokens directly.

- `create_account_screen.dart`
  - Currently a static/UX screen; does not call the API yet.
  - Future:
    - Could be removed or wired as an alternate entry into `SignupScreen`.

- `account_screen.dart`
  - Uses `AuthService.logout` (local token clearing).
  - Future:
    - No direct endpoint mapping; acts as a shell for profile/my-posts which will consume API data.

- `profile_screen.dart`
  - Currently uses placeholder/local profile content.
  - Future endpoints:
    - Read-only profile details could map to:
      - `GET /admin/users/:user_id` (for admin views), or
      - A future non-admin `GET /api/me`/`/api/users/:id` endpoint.

### Feed, discovery, and video playback

- `feed_screen.dart`
  - Currently displays hard-coded `_BuzzCard` demo content.
  - Target endpoints:
    - `GET /api/feed` — to replace the local list with the real video feed.
    - `GET /api/videos/:video_id/votes` — to hydrate like counts if needed.
    - `GET /api/videos/:video_id/comments` — to load counts or previews.

- `discover_screen.dart`
  - Currently static search UI with local demo content.
  - Target endpoints:
    - `GET /api/search?tag=...&username=...` — for real discovery results.

- `full_screen_view.dart` and `full_screen_view_screen.dart`
  - Present full-screen views over a selected card.
  - Target endpoints:
    - Will consume data originally loaded from `GET /api/feed` or `GET /api/search`.
    - May call `GET /api/videos/:video_id/comments` when integrating comments inline.

### Creation, trimming, and publishing

- `create_screen.dart`
  - Integrates `camera` and `image_picker` to capture or pick local video files.
  - Target responsibilities (no direct API calls yet):
    - Upload finalized local file to Cloudinary (client-side SDK or simple HTTP) to obtain `input_url`.
    - Then delegate upload to `PublishScreen` → `VideoService.uploadVideo`.

- `video_trim_screen.dart`
  - Purely local trimming with `video_trimmer`; no direct API interaction.
  - Target responsibilities:
    - Ensure the trimmed file is what gets uploaded to Cloudinary before enqueueing with the backend.

- `publish_screen.dart`
  - Currently simulates processing/upload with local timers and status text.
  - Target endpoints (via `VideoService`):
    - Cloudinary client upload (to get `input_url` — outside the UniBuzz API).
    - `POST /api/videos/upload?input_url=...&caption=...&tags=...` — enqueue video for processing.
    - `GET /api/videos/:video_id/status` — poll for processing status and update the progress UI based on `pending`/`complete`/`failed`.

- `edit_post_screen.dart`
  - Currently a local-only edit UI for a video card.
  - Future endpoints:
    - Would depend on backend support for updating video metadata (e.g., `PUT /api/videos/:video_id`), which is not yet defined in `Integration.md`.

### Engagement: comments, votes, reports

- `comment_section.dart`
  - Displays and manages comments in a bottom sheet UI.
  - Target endpoints:
    - `GET /api/videos/:video_id/comments` — load comment list.
    - `POST /api/videos/:video_id/comments` — add a new comment.
    - `PUT /api/comments/:comment_id` — edit a comment.
    - `DELETE /api/comments/:comment_id` — delete a comment.

- `report_screen.dart`
  - Lets users pick a report reason and submit it.
  - Target endpoints:
    - `POST /api/videos/:video_id/report` — send reports with `reason` and optional `custom_reason`.

- `my_posts_screen.dart`
  - Currently shows demo/local posts.
  - Future endpoints:
    - Would likely map to a future `GET /api/videos?user_id=...` (not yet defined) or similar.

- Voting controls inside feed/full-screen views
  - Target endpoints:
    - `POST /api/videos/:video_id/vote` — upvote/downvote.
    - `GET /api/videos/:video_id/votes` — read aggregated counts.

### Admin-related flows

- There is currently **no dedicated admin UI** in the Flutter app.
  - Future admin screens could target:
    - `GET /admin/reports`
    - `DELETE /admin/videos/:video_id`
    - `GET /admin/users`, `GET /admin/users/:user_id`
    - `POST /admin/users/:user_id/suspend`, `/unsuspend`, `/ban`
    - `DELETE /admin/users/:user_id`

