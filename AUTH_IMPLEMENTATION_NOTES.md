# Current Customer App Auth (fixitzed_app)
- Login UI: `lib/screens/sign_in_screen.dart` posts credentials via `AuthService().login` and routes to `/home` on success; splash (`lib/screens/splash_screen.dart`) always routes to `/auth` or onboarding with no token check.
- Auth service: `lib/services/auth_service.dart` calls `POST /login`, `POST /register`, password flows, and `POST /logout`. Tokens are parsed from several possible JSON keys and persisted via `SessionManager`.
- Token storage: `lib/services/session_manager.dart` saves `auth_token` in `SharedPreferences` (plain text). Many services pull the token directly from SharedPreferences; there is no secure storage.
- Network layer: direct `http` calls across many services; headers with `Authorization: Bearer <token>` are added ad hoc per service. There is no interceptor; each request fetches the token separately.
- Session handling: `SessionGuard` is manually invoked in many services to force logout on 401/419; `SessionRedirector` listens for auth events but redirects to `/signin` (route mismatch because login route is `/auth`).
- Logout: `AuthService.logout` posts to `/logout` (if a token exists), then clears `auth_token` and FCM token via `SessionManager.finalizeLogout`.
- Persistence on restart: the splash screen does not consider stored tokens, so users are always sent to login even if a token exists. There is no refresh flow.

# Current Fixer App Auth (Fixitzed-Fixer-App)
- Login UI: `lib/screens/sign_in_screen.dart` uses `AuthService().login` against `/api/login`, then checks `/api/me` to confirm the user has a `fixer` role before routing to `/home`. Splash (`lib/screens/splash_screen.dart`) always sends users to `/signin` or onboarding; stored tokens are ignored.
- Auth service: `lib/services/auth_service.dart` posts to `/api/login`, `/api/register`, `/api/password/...`, `/api/logout`, and uses `ApiClient` for authenticated requests.
- Token storage: `lib/services/session_manager.dart` saves `auth_token` in `SharedPreferences`; `ApiClient.setToken` writes there. No secure storage is used.
- Network layer: `lib/services/api_client.dart` wraps `http` and attaches `Authorization: Bearer <token>` if present on each call. `SessionGuard` triggers forced logout on 401/419. No retry/refresh logic exists.
- Logout: `AuthService.logout` posts to `/api/logout` then clears the token and broadcasts logout events.
- Persistence on restart: splash ignores stored tokens; there is no auto-login or refresh flow.

# Backend Auth Overview (READ-ONLY)
- Laravel Sanctum API (`routes/api.php`): `POST /api/login`, `POST /api/register`, `POST /api/password/forgot`, `POST /api/password/reset`, `POST /api/logout`, `GET /api/me`, profile update via `PATCH /api/me`, password change via `/api/password` or `/api/me/password`.
- Login returns JSON with `success`, `token` (plainTextToken), `user`, and `requires_verification`. Registration also returns a token. MFA challenge via `POST /api/login/mfa` (returns `mfa_required` and `mfa_token`).
- Logout deletes the current access token; `UserSessionManager::revokeActiveTokens` is invoked on login to enforce single-session tokens.
- There is **no refresh endpoint**; access tokens are long-lived until revoked or logged out. Authenticated routes require `Authorization: Bearer <token>` with Sanctum.

# Gaps preventing “login once, stay logged in”
- Tokens are stored in `SharedPreferences` (unencrypted) in both apps; no use of `flutter_secure_storage`.
- Splash/startup flows always send users to login/onboarding and never attempt to reuse or validate stored tokens.
- No refresh-token handling or retry on 401; unauthorized responses force logout without a silent recovery path.
- Auth header attachment is ad hoc (customer app) and lacks a centralized interceptor with retry guardrails.
- Session redirectors point to `/signin` while the customer login route is `/auth`, risking navigation issues after forced logout.
- Logout/token clearing is manual across services; there is no single source of truth for auth state or storage namespace separation between the two apps.

---

## Customer App — Final Auth Flow
- **Storage**: Sanctum token stored via `flutter_secure_storage` in `lib/services/token_storage.dart` under `customer_api_token`, migrating any legacy `auth_token` from `SharedPreferences` on first read. All token reads/writes now go through `TokenStorage` (via `SessionManager`).
- **HTTP/Auth**: `lib/services/api_client.dart` injects `Authorization: Bearer <token>` for authenticated calls; `AuthService` and other services draw tokens from `TokenStorage`. `SessionGuard` triggers a forced logout on 401/419, clearing the secure token.
- **Startup**: `lib/screens/splash_screen.dart` checks `TokenStorage.getToken()`. If absent → `/auth`; if present, it probes `/api/me` to validate and routes to `/home` on success, otherwise clears/redirects to `/auth`. Onboarding is still shown first when unseen.
- **Unauthorized**: 401/419 invokes `SessionGuard` → `SessionManager.ensureForcedLogout` → token cleared + broadcast; `SessionRedirector` now routes to `/auth` to align with the login route.
- **Logout**: `AuthService.logout` calls `/logout` (best-effort), clears FCM + secure token via `SessionManager.finalizeLogout`, and navigation flows send the user to `/auth` with the stack cleared.

## Fixer App — Final Auth Flow
- **Storage**: Sanctum token stored via `flutter_secure_storage` in `lib/services/token_storage.dart` under `fixer_api_token` with migration from legacy `auth_token`. `SessionManager` delegates to this storage for all token operations.
- **HTTP/Auth**: `lib/services/api_client.dart` reads tokens from `SessionManager` (secure storage) and attaches `Authorization` automatically for authenticated requests; `SessionGuard` forces logout on 401/419.
- **Startup**: `lib/screens/splash_screen.dart` checks secure token; if none → `/signin` (or onboarding if not seen). If present, it calls `/api/me`; 200 → `/home`, otherwise the guard clears token and routes to `/signin`.
- **Unauthorized**: Any 401/419 via `SessionGuard` clears the secure token and emits auth events; `SessionRedirector` keeps routing to `/signin`.
- **Logout**: `AuthService.logout` posts to `/api/logout`, then clears secure token via `SessionManager.finalizeLogout` and relies on auth events/navigation to return to `/signin` with history cleared.
