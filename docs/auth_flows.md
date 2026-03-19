## Auth flows & `AuthService` usage

- **Service**: `lib/services/auth_service.dart`
  - Implements `register`, `login`, `refreshAccessToken`, `getAccessToken`, `getRefreshToken`, `setAccessToken`, and `logout`.
  - Centralizes base URL `https://unibuzz-api.onrender.com` and JSON error handling via `_processResponse`.

### Where auth is used today

- **App bootstrap**
  - `lib/main.dart`:
    - `MyApp._checkAuth()` calls `AuthService.getAccessToken()` at startup to decide between `PrimaryNavShell` (authenticated) and `LoginScreen`.

- **Login**
  - `lib/interfaces/login_screen.dart`:
    - Calls `AuthService.login(...)` in `_handleLogin()`.
    - On success, pushes `PrimaryNavShell` with `Navigator.pushReplacement`.
    - On failure, surfaces the error message in the UI; there is **no token refresh handling** here (as expected).

- **Signup**
  - `lib/interfaces/signup_screen.dart`:
    - Calls `AuthService.register(...)` in `_handleSignup()`.
    - On success, immediately navigates to `PrimaryNavShell` without auto-login or token fetch; this assumes backend returns a successful registration without issuing tokens.

- **Logout**
  - `lib/interfaces/account_screen.dart`:
    - Calls `AuthService.logout()` in `_handleLogout()` to clear `access_token` and `refresh_token`, then navigates back to `LoginScreen` with `pushAndRemoveUntil`.

### Identified gaps and notes

- **Refresh token usage**
  - `AuthService.refreshAccessToken()` exists but is **not used** anywhere in the app yet.
  - There is no shared API client layer that automatically retries on `401` using the refresh token; future network code (e.g., a `VideoService`) should centralize this behavior.

- **Post-registration flow**
  - After `register`, the app goes directly to `PrimaryNavShell` without storing tokens.
  - Depending on backend behavior, we may need to:
    - Either log in immediately after successful registration (preferred), or
    - Update the backend to return tokens from `/auth/register` and have `AuthService.register` store them.

- **Global auth state**
  - All auth checks are **on startup only** via `MyApp._checkAuth()`.
  - Future API integrations should consider:
    - Handling `401` responses by triggering a token refresh and, if that fails, redirecting to `LoginScreen`.
    - Optionally adding a lightweight auth state notifier if more complex flows are introduced later.

