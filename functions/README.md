# AmongApp Cloud Functions

Backend for the authentication flows in the AmongApp Flutter app.

## Functions

| Function                 | Purpose                                                          |
| ------------------------ | ---------------------------------------------------------------- |
| `sendSignupOtp`          | Sends a secure 6-digit OTP to verify a newly created account. The account stays inactive (`emailVerified = false`) until the code is confirmed. |
| `verifySignupOtp`        | Verifies the signup OTP and **activates** the account (sets `emailVerified = true`). Single-use, 5-minute expiry, 5-attempt limit. |
| `sendPasswordResetOtp`   | Validates the email, enforces the 60s resend cooldown, generates a secure 6-digit OTP, stores a **salted hash** (never the plaintext) and emails it. |
| `verifyPasswordResetOtp` | Verifies the OTP with constant-time comparison. Enforces 5-minute expiry and a 5-attempt limit; marks the record verified. |
| `resetPassword`          | Applies the new password via Firebase Auth (bcrypt-equivalent hashing), requires a previously verified OTP and consumes the code (single-use). |
| `sendChangePasswordOtp`  | Sends a 6-digit OTP to the **signed-in** user's registered email before a password change. Rejects callers who are not signed in or do not own the account. |
| `verifyChangePasswordOtp`| Verifies the change-password OTP (same expiry/attempt/single-use rules). |
| `changePassword`         | Applies a new password for the signed-in user after a verified change-password OTP. Consumes the code. |

Each OTP record is tagged with a `purpose` (`signup` | `reset` | `changePassword`)
so a code issued for one flow can never be used for another.

## Local development (Functions Emulator)

```bash
cd functions
npm install
cp .env.example .env       # fill in real SMTP credentials (or use Mailtrap)
npm run serve              # builds and starts the Functions emulator on :5001
```

Then run the Flutter app pointed at the emulator:

```bash
flutter run --dart-define=USE_FUNCTIONS_EMULATOR=true
```

> The Android emulator resolves `localhost` → `10.0.2.2` automatically. On a
> physical device, use your machine's LAN IP.

## Deployment

```bash
cd functions
npm install
npm run deploy
```

Set secrets with the Firebase CLI instead of committing them:

```bash
firebase functions:secrets:set SMTP_HOST
firebase functions:secrets:set SMTP_PORT
firebase functions:secrets:set SMTP_USER
firebase functions:secrets:set SMTP_PASS
firebase functions:secrets:set MAIL_FROM
firebase functions:secrets:set APP_NAME
```

Then reference them as environment variables in the function runtime
(`functions:secrets:set` values are available via `process.env` after
`firebase functions:secrets:set` + redeploy).

## Data model (Firestore, `otpRequests/<email>`)

| Field         | Type     | Notes                                             |
| ------------- | -------- | ------------------------------------------------- |
| `purpose`     | string   | `signup`, `reset` or `changePassword` — prevents cross-flow reuse |
| `otpHash`     | string   | SHA-256 of `salt:otp` — plaintext never stored    |
| `salt`        | string   | Per-record random salt                            |
| `attempts`    | number   | Incremented on each verification attempt          |
| `verified`    | boolean  | Set true only after successful OTP verification   |
| `expiresAt`   | Timestamp| 5 minutes from generation; auto-invalidated       |
| `lastSentAt`  | Timestamp| Used for the 60s resend cooldown                 |
| `createdAt`   | Timestamp|                                                   |

## Firestore security

Keep the collection locked down. The functions use the Admin SDK, so the
client never reads or writes these documents directly. A minimal ruleset:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /otpRequests/{email} {
      allow read, write: if false;
    }
  }
}
```

## Email provider

Any SMTP provider works (Gmail App Password, Mailtrap, Brevo, SendGrid relay).
Email is sent asynchronously with `nodemailer`; delivery failures delete the
pending code and surface a friendly error to the user. HTML and plain-text
templates live in `src/templates.ts` (all user content is HTML-escaped).
