# Troubleshooting — AmongApp

## Build Issues

### 1. Gradle Build Failure (Android)

**Error:** `Could not resolve all dependencies for configuration ':app:classpath'`

**Fix:**
- Ensure `android/build.gradle.kts` uses the correct Kotlin version
- Run `flutter clean && flutter pub get`
- Check that `google-services.json` is present in `android/app/`

### 2. Firebase Not Configured

**Error:** `FirebaseException: [core/not-initialized] Firebase has not been correctly initialized.`

**Fix:**
- Run `flutterfire configure` to regenerate `firebase_options.dart`
- Ensure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are in the correct locations
- Check that `DefaultFirebaseOptions.currentPlatform` returns valid options for your platform

### 3. Cloud Functions Not Found

**Error:** `FirebaseFunctionsException: not-found`

**Fix:**
- Deploy Cloud Functions: `cd functions && npm run deploy`
- Verify function names match those in `otp_api.dart` (e.g., `sendSignupOtp`, `verifySignupOtp`)
- Check Firebase project ID matches `firstfirebase-5880d`

### 4. OTP Not Sending

**Error:** `OtpApiException: Could not reach the server`

**Fix:**
- Check internet connection
- Verify Cloud Functions are deployed and enabled
- On unsupported platforms (Windows/Linux), the REST fallback is used — ensure the project ID is correct
- Check Firebase Functions logs for errors

### 5. Image Upload Fails

**Error:** `FirebaseException: storage/unauthorized`

**Fix:**
- Check Firebase Storage security rules
- Ensure user is authenticated before uploading
- Verify `StorageService` is initialized with correct bucket (`firstfirebase-5880d.firebasestorage.app`)

---

## Navigation & Grid Layout Issues

### 1. Bottom Nav Too Tall / Too Short

The navbar height is tuned in `lib/widgets/bottom_nav.dart` (both the `Container` `height` and the `SafeArea` `minimum.bottom`). Adjust all three together: container height, inner `EdgeInsets.all(8)` padding, and the pill's `top`/`bottom` offsets.

### 2. `unnecessary_underscores` / `unnecessary double` Lint Infos
Shown in `TweenAnimationBuilder` callbacks like `(_, __, ___)`.
- **Fix:** Use a single underscore for unused params where the type allows it (`(_, _, _)`), or name the third param and use it. Keep the analyzer clean with `flutter analyze`.

### 3. `withOpacity` is Deprecated
Newer Flutter lints flag `Color.withOpacity(alpha)`.
- **Fix:** Use `color.withValues(alpha: X)` — this is the codebase's current convention (matches `app_theme.dart`, `summary_card.dart`, etc.).

### 4. Grid Items Render With Wrong Aspect / Overflow
`ItemsGridPage` uses `childAspectRatio: 0.72` in the `SliverGridDelegateWithFixedCrossAxisCount`.
- **Fix:** If cards clip or leave space, tune `childAspectRatio` (higher = taller cards, lower = shorter). Card content is clipped via `ClipRRect`/`Container` so long descriptions never overflow.

---

## Platform-Specific Issues

### iOS

**Issue:** App crashes on launch with Firebase
- Ensure `GoogleService-Info.plist` is added via Xcode (not just file copy)
- Run `pod install` in `ios/` directory

### Windows / Linux

**Issue:** Cloud Functions plugin not available
- The app uses REST API fallback on these platforms
- Ensure `http` package is in `pubspec.yaml`
- Check that the REST endpoint URL is correct in `otp_api.dart`

### Web

**Issue:** CORS errors when calling Cloud Functions
- Deploy Cloud Functions with CORS headers
- Or use Firebase Hosting to proxy requests

---

## Common Runtime Errors

### 1. `Null check operator used on a null value`

**Cause:** Accessing `currentUser` when no user is signed in.

**Fix:** Always null-check `_auth.currentUser` before using it. The `DashboardScreen` has an auth guard that redirects to login if null.

### 2. `setState() called after dispose()`

**Cause:** Async operations completing after the widget is disposed.

**Fix:** Always check `if (!mounted) return;` after await calls before calling `setState()`. The codebase already does this consistently.

### 3. `A RenderFlex overflowed by X pixels on the bottom`

**Cause:** Content too tall for the screen.

**Fix:** Wrap content in `SingleChildScrollView` or `ListView`. The auth screens use `AuthScaffold` which handles this automatically.

### 4. Firestore Permission Denied

**Error:** `PERMISSION_DENIED: Missing or insufficient permissions`

**Fix:** Check Firestore security rules. Items collection should allow:
- Read: Any authenticated user
- Write: Only the document owner (ownerUid matches auth UID)

---

## Development Tips

### Hot Reload Not Working
- Run `flutter clean && flutter run`
- Check for syntax errors in the file you're editing

### Firebase Emulator (Local Testing)
To use the Firebase emulator locally:
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Start emulator: `firebase emulators:start`
3. Set `USE_FUNCTIONS_EMULATOR=true` in your environment
4. The app will connect to `localhost:5001` for Cloud Functions

### Running Tests
```bash
flutter test
```

### Analyzing Code
```bash
flutter analyze
```

### Building for Release
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

---

## Error Code Reference

### Firebase Auth Error Codes
| Code | Meaning | User Message |
|------|---------|-------------|
| `invalid-email` | Bad email format | Please enter a valid email address. |
| `user-disabled` | Account disabled | This account has been disabled. |
| `user-not-found` | No account found | No account found with this email address. |
| `wrong-password` | Wrong password | Incorrect email or password. |
| `invalid-credential` | Bad credentials | Incorrect email or password. |
| `email-already-in-use` | Duplicate email | An account with this email already exists. |
| `weak-password` | Password too short | Password is too weak. Please use at least 8 characters. |
| `too-many-requests` | Rate limited | Too many attempts. Please try again later. |
| `network-request-failed` | No internet | Network error. Check your connection and try again. |

### Cloud Functions Error Codes
| Code | Meaning | User Message |
|------|---------|-------------|
| `not-found` | Function or user not found | No account found with this email address. |
| `resource-exhausted` | Rate limited | Too many attempts. Please try again later. |
| `unavailable` | Service down | Service temporarily unavailable. Please try again. |
| `unauthenticated` | Not signed in | You are not signed in. |
| `PERMISSION_DENIED` | Unauthorized action | You can only change the password for your own account. |
| `DEADLINE_EXCEEDED` | OTP expired | This code has expired. Please request a new one. |
