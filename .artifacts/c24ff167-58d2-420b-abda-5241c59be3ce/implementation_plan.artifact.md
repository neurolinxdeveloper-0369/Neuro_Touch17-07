# Implementation Plan - Actual OTP Sending via SMS Gateway

The current system only simulates OTP sending by logging to the console. This plan will integrate a real SMS gateway to send OTPs to users' mobile phones.

## User Review Required

> [!IMPORTANT]
> You will need an account with an SMS service provider (like Twilio, Fast2SMS, etc.) and their API credentials to make this work.
>
> Please let me know if you have a preferred provider. I will use **Twilio** as a default placeholder in this plan.

## Proposed Changes

### [Backend Configuration]

#### [MODIFY] [config.go](file:///B:/IoT_Neuro Touch/IoT_Neuro Touch/backend/config/config.go)
- Add `SmsAccountSid`, `SmsAuthToken`, and `SmsFromNumber` (or equivalent for your provider) to the `Config` struct.
- Load these values from environment variables in `LoadConfig()`.

#### [MODIFY] [.env.example](file:///B:/IoT_Neuro Touch/IoT_Neuro Touch/.env.example)
- Add placeholders for the new SMS configuration variables.

### [Auth Controller]

#### [MODIFY] [auth_controller.go](file:///B:/IoT_Neuro Touch/IoT_Neuro Touch/backend/controllers/auth_controller.go)
- Implement a helper function `sendSMS(to, message)` that makes an HTTP POST request to the SMS provider's API.
- Update the `SendOTP` function to call `sendSMS` instead of just logging to the console.

## Verification Plan

### Manual Verification
1. Start the backend with valid SMS credentials in `.env`.
2. Trigger the `SendOTP` endpoint from the mobile app or via Postman.
3. Verify that an SMS is received on the target phone number.
4. Check backend logs for any API errors from the SMS provider.
