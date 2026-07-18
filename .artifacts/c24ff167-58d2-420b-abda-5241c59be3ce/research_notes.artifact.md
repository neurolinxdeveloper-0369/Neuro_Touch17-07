# OTP Sending Research

## Current State
The `SendOTP` function in `backend/controllers/auth_controller.go` (lines 173-209) generates a 6-digit OTP and stores it in the database, but it does **not** send it to the user's mobile device.

Instead, it logs the OTP to the console:
```go
// Simulate sending by logging to terminal
log.Printf("[SIMULATED OTP] Verification code for phone %s is: '%s'", phone, otpCode)
```

## Missing Components
1. **SMS Gateway Integration**: No code exists to communicate with an external SMS provider (e.g., Twilio, Vonage, Fast2SMS).
2. **Configuration**: The `Config` struct in `backend/config/config.go` lacks fields for SMS API keys or secrets.
3. **Environment Variables**: `.env.example` does not contain any placeholders for SMS settings.

## Potential Solutions
1. **Twilio**: Global provider, reliable, but requires account setup and credits.
2. **Fast2SMS / MSG91**: Popular in India, easy HTTP API.
3. **Firebase Phone Auth**: Could be used, but would require a significant refactor of the current custom OTP logic.

## Recommended Action
Integrate a simple SMS gateway service by:
1. Adding configuration for the gateway in `config.go`.
2. Implementing a `sendSMS` helper function.
3. Updating `SendOTP` to call `sendSMS`.
