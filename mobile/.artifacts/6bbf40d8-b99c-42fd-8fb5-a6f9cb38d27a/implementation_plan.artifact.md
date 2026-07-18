# Implementation Plan - Auth Flow & Security Fixes

This plan implements the fixes identified in the [Auth Flow Audit](file:///B:/IoT_Neuro%20Touch/IoT_Neuro%20Touch/mobile/.artifacts/6bbf40d8-b99c-42fd-8fb5-a6f9cb38d27a/auth_flow_audit.artifact.md).

## User Review Required

> [!IMPORTANT]
> - **Security Change**: The app will no longer receive the OTP code from the backend. This requires the backend to be updated (or mock data adjusted) to not return the code.
> - **Navigation Change**: Manual navigation calls in Login and OTP screens are being removed. `GoRouter` will now centrally manage all redirects based on the authentication state.

## Proposed Changes

### [Component] Data Layer

#### [MODIFY] [auth.repository.dart](file:///B:/IoT_Neuro%20Touch/IoT_Neuro%20Touch/mobile/lib/data/repositories/auth.repository.dart)
- Change `sendOtp` return type from `Future<String?>` to `Future<void>`.
- Remove code that extracts `otp` from the response.

---

### [Component] Controllers

#### [MODIFY] [auth.controller.dart](file:///B:/IoT_Neuro%20Touch/IoT_Neuro%20Touch/mobile/lib/controllers/auth.controller.dart)
- Update `sendOtp` to match repository changes.
- In `_init()`, add `_googleSignIn.signInSilently()` to automatically restore Google sessions if local tokens are missing or need refreshing.

---

### [Component] Routing & Navigation

#### [MODIFY] [app_router.dart](file:///B:/IoT_Neuro%20Touch/IoT_Neuro%20Touch/mobile/lib/core/router/app_router.dart)
- Update `redirect` logic to handle navigation from `/splash` to `/dashboard` or `/login` once the `AuthStatus` is resolved.

#### [MODIFY] [splash_screen.dart](file:///B:/IoT_Neuro%20Touch/IoT_Neuro%20Touch/mobile/lib/presentation/splash/splash_screen.dart)
- Remove the fixed `Future.delayed` timer for navigation.
- The screen will now purely show the animation, and `GoRouter` (via the `redirect` function and `refreshListenable`) will trigger the move to the next screen as soon as the `AuthController` finishes initialization.

#### [MODIFY] [login_screen.dart](file:///B:/IoT_Neuro%20Touch/IoT_Neuro%20Touch/mobile/lib/presentation/auth/login_screen.dart)
- Remove the debug SnackBar that displayed the OTP code.
- Remove the `ref.listen` block that manually called `context.go('/dashboard')`.

#### [MODIFY] [otp_verify_screen.dart](file:///B:/IoT_Neuro%20Touch/IoT_Neuro%20Touch/mobile/lib/presentation/auth/otp_verify_screen.dart)
- Remove the `ref.listen` block that manually called `context.go('/dashboard')`.

---

## Verification Plan

### Automated Tests
- Run `analyze_file` on all modified files to ensure no syntax errors or breaking changes in the API contracts.

### Manual Verification
- **Cold Boot**: Verify Splash screen shows and then transitions to either Dashboard (if logged in) or Login (if logged out).
- **Google Sign-In**: Verify successful login redirects to Dashboard without manual `context.go` calls.
- **OTP Flow**: Verify OTP entry redirects to Dashboard upon success.
- **Security**: Verify no OTP code is visible in logs or UI after the "Send OTP" action.
