# KAH KEN SHA NEY (AmongApp)

AI and ML-powered application that turns your lost into found, with OTP-based authentication.

## Features

- **AI Camera Scanner** — Point your camera at an item to match it against active reports
- **OTP Authentication** — Secure email-based verification for signup, password reset, and password change
- **Smart Matching** — AI-powered matching of lost and found items
- **Real-time Dashboard** — Overview of reports, AI suggestions, and campus announcements
- **Status Tracking** — Live 6-stage tracker (Submitted → Pending Verification → Verified → Matched → Claimed → Archived) driven by Firestore, updated in real time
- **Recent Reports** — Your latest reports on the Home tab (newest first) with type, name, status, and date; "View All Reports" jumps to the Reports tab
- **Account Menu** — Avatar menu with Profile, Change Password, and a confirm-enabled Log out back to the login screen

## Getting Started

### Prerequisites

- Flutter SDK 3.12.2 or later
- Dart SDK 3.12.2 or later
- Firebase project with Authentication and Cloud Functions enabled
- SMTP server for email delivery (or use the emulator logger transport)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd amongapp

# Install dependencies
flutter pub get

# Configure Firebase (requires FlutterFire CLI)
dart pub global activate flutterfire_cli
flutterfire configure

# Run the app
flutter run
```

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Firebase Authentication** (Email/Password provider)
3. Enable **Cloud Functions** (Node.js 20 runtime)
4. Run `flutterfire configure` to generate `lib/firebase_options.dart`
5. Deploy Cloud Functions: `cd functions && npm run deploy`

### Cloud Functions Configuration

Set SMTP secrets for email delivery:

```bash
firebase functions:secrets:set SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS MAIL_FROM APP_NAME
```

See `functions/.env.example` for available configuration options.

### Android Release Signing

1. Generate a keystore:
   ```bash
   keytool -genkey -v -keystore release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias amongapp
   ```

2. Set environment variables:
   ```bash
   export KEYSTORE_PATH=/path/to/release-key.jks
   export KEYSTORE_PASSWORD=<your-password>
   export KEY_ALIAS=amongapp
   export KEY_PASSWORD=<your-password>
   ```

3. Build a release APK:
   ```bash
   flutter build apk --release
   ```

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

Tests for validators, cooldown timer, OTP input, and auth scaffold layout are fully mocked and do not require live Firebase.

## Project Structure

```
lib/
  main.dart                  — App entry point with Firebase init
  mainpage.dart              — Public landing page
  firebase_options.dart      — Firebase configuration
  screens/
    dashboard.dart           — Authenticated home with welcome overlay
    auth/                    — Login, signup, OTP, password reset flows
  pages/                     — Tab content (home feed, reports, AI scan, messages, profile)
  services/
    auth_service.dart        — Authentication abstraction + Firebase implementation
    otp_api.dart             — OTP backend communication (Cloud Functions)
  widgets/                   — Reusable UI components
  theme/app_theme.dart       — Design tokens and Material 3 theme
  utils/
    validators.dart          — Input validation
    cooldown_timer.dart      — Resend cooldown logic

functions/
  src/
    index.ts                 — Cloud Functions entry point
    otp.ts                   — OTP generation and hashing
    email.ts                 — SMTP email delivery
    validation.ts            — Server-side input validation
    templates.ts             — HTML email templates

test/
  widget_test.dart           — Widget and navigation tests
  validators_test.dart       — Validator unit tests
  cooldown_timer_test.dart   — Cooldown timer tests
  auth_scaffold_layout_test.dart — Layout responsiveness tests
```

## Architecture

- **Service Layer**: `AuthService` interface with `FirebaseAuthService` implementation. Injectable for testing.
- **OTP Backend**: `OtpApi` abstraction over Cloud Functions. Supports both `cloud_functions` plugin (Android/iOS/macOS/web) and HTTPS REST fallback (Windows/Linux).
- **Widget Layer**: Reusable, stateless and stateful widgets with consistent theming via `AppColors`.
- **Navigation**: Manual `Navigator` routing with `pushAndRemoveUntil` for auth state transitions.

## License

Private — All rights reserved.
