# Auth Flow Audit: Splash -> Login -> Google Sign-In

This audit reviews the end-to-end authentication flow for the Neuro Touch Flutter app.

## Summary Scores
| Category | Score | Notes |
| :--- | :--- | :--- |
| **Correctness** | 7/10 | Redundant navigation logic and splash race conditions. |
| **Security** | 3/10 | **CRITICAL**: OTP is returned in the API response. |
| **Performance** | 8/10 | Efficient state management with Riverpod. |
| **Code Quality** | 7/10 | Good repository pattern, but too many hardcoded UI values. |
| **UI/UX** | 8/10 | Polished animations, but inconsistent theme handling. |

---

## Critical & High Severity Issues

### 1. OTP Leak in API Response
> [!CAUTION]
> **Severity: High (Security)**
> The `AuthRepository.sendOtp` method returns the OTP string directly from the API response.
>
> **Risk**: An attacker can intercept the network traffic (or simply look at the response on a rooted device/proxy) and gain access to any account without needing the actual SMS/Email.

**File**: [auth.repository.dart](file:///B:/IoT_Neuro%20Touch/IoT_Neuro%20Touch/mobile/lib/data/repositories/auth.repository.dart)
```diff
-  Future<String?> sendOtp(String phone) async {
-    final resp = await _api.post(ApiConstants.sendOtp, data: {'phone': phone});
-    final data = resp.data as Map<String, dynamic>;
-    if (data['success'] != true) throw Exception(data['error']);
-    return data['otp'] as String?; // <--- REMOVE THIS
-  }
+  Future<void> sendOtp(String phone) async {
+    final resp = await _api.post(ApiConstants.sendOtp, data: {'phone': phone});
+    final data = resp.data as Map<String, dynamic>;
+    if (data['success'] != true) throw Exception(data['error']);
+  }
```

### 2. Redundant & Conflicting Navigation
> [!WARNING]
> **Severity: Medium (Correctness)**
> Both the `GoRouter` (via `refreshListenable`) and individual screens (`SplashScreen`, `LoginScreen`, `OtpVerifyScreen`) are calling `context.go('/dashboard')`.
>
> **Risk**: This can cause double-navigation, race conditions where the screen tries to navigate before the router has redirected, or unexpected UI pops.

**Recommended Fix**: Remove manual navigation from screens and let the `routerProvider` handle all redirects based on `authControllerProvider` state.

---

## Medium & Low Severity Issues

### 3. Splash Screen Auth Race Condition
**Severity: Medium (UX)**
The `SplashScreen` uses a fixed `Future.delayed` of 2.4s. If the `_init()` check in `AuthController` (which is async) takes longer than 2.4s, the app might incorrectly default to `/login`.

**Improved Logic**: Wait for `AuthStatus` to change from `initial` to something else.

```dart
// In SplashScreen initState
ref.listenManual(authControllerProvider, (prev, next) {
  if (next.status != AuthStatus.initial && next.status != AuthStatus.loading) {
     // Now it's safe to navigate
  }
});
```

### 4. Missing Google Silent Sign-In
**Severity: Low (UX)**
The app doesn't try to sign in silently on startup. Users have to tap "Google" every time if their local token expires.

**Improved Logic**: Add `_googleSignIn.signInSilently()` to `AuthController._init()`.

### 5. Inconsistent Theme Handling
**Severity: Low (UI)**
`LoginScreen` has a hardcoded `Color(0xFF000000)` background. If the user prefers a Light theme, this screen will look disjointed from the rest of the app.

---

## Refactor Plan

### Phase 1: Security Fix (Immediate)
- Modify `AuthRepository` and `AuthController` to stop returning/receiving OTP from the API.
- Update `LoginScreen` to remove the "Debug: OTP is..." SnackBar.

### Phase 2: Navigation Consolidation
- Remove `ref.listen` navigation logic from `LoginScreen` and `OtpVerifyScreen`.
- Remove `Future.delayed` navigation from `SplashScreen`.
- Update `GoRouter.redirect` to handle the transition from `/splash` once the auth state is resolved.

### Phase 3: UI & Resilience
- Replace `MediaQuery.sizeOf(context)` multipliers with the new `ResponsiveLayout` or theme-based spacing.
- Implement `signInSilently` for Google.

---

## Test Cases & Integration Checklist

### Test Cases
- [ ] **Cold Start (Logged In)**: Splash -> Dashboard (No login visible).
- [ ] **Cold Start (Logged Out)**: Splash -> Login.
- [ ] **Google Sign-In Cancel**: Ensure state returns to `unauthenticated` and no infinite loading.
- [ ] **Token Expiry**: Trigger a 401, ensure refresh works, and UI doesn't flicker.
- [ ] **Refresh Failure**: Ensure app redirects to `/login` immediately when refresh token is invalid.
- [ ] **Invalid OTP**: Enter wrong code, ensure error message shows and boxes clear.

### Integration Checklist
- [ ] Backend OTP endpoint updated to NOT return the code.
- [ ] Google Client ID configured in `.env` or as `--dart-define`.
- [ ] Firebase/Google Console configured with correct SHA-1 for Android.
- [ ] `StorageService` successfully persists `UserModel` and tokens across restarts.
