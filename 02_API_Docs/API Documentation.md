# API Documentation — AmongApp

## Authentication API

### `AuthService` (Abstract)
**File:** `lib/services/auth_service.dart`

The core authentication contract implemented by `FirebaseAuthService`.

#### Methods

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `currentUser` | — | `User?` | Currently signed-in Firebase user, or null |
| `login` | `email`, `password` | `AuthResult` | Sign in with email/password |
| `register` | `fullName`, `email`, `password` | `AuthResult` | Create new account |
| `signOut` | — | `void` | Sign out current user |
| `resendSignupOtp` | `email` | `void` | Resend email verification OTP |
| `verifyEmailOtp` | `email`, `otp` | `void` | Verify email with OTP code |
| `sendPasswordResetOtp` | `email` | `void` | Send password reset OTP |
| `verifyPasswordResetOtp` | `email`, `otp` | `void` | Verify reset OTP |
| `resetPassword` | `email`, `otp`, `newPassword` | `void` | Apply new password after reset |
| `sendChangePasswordOtp` | `email` | `void` | Send change-password OTP |
| `verifyChangePasswordOtp` | `email`, `otp` | `void` | Verify change-password OTP |
| `changePassword` | `email`, `otp`, `newPassword` | `void` | Apply new password after change |

#### `AuthResult` (Sealed Class)
```dart
sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  const AuthSuccess({this.user});
  final User? user;
}

class AuthFailure extends AuthResult {
  const AuthFailure(this.message);
  final String message;
}
```

#### `AuthException`
Thrown by OTP/password-recovery methods with a user-friendly message.
```dart
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}
```

#### Error Codes → Messages
| Firebase Error Code | User Message |
|---------------------|-------------|
| `invalid-email` | Please enter a valid email address. |
| `user-disabled` | This account has been disabled. |
| `user-not-found` | No account found with this email address. |
| `wrong-password` / `invalid-credential` | Incorrect email or password. |
| `email-already-in-use` | An account with this email already exists. |
| `weak-password` | Password is too weak. Please use at least 8 characters. |
| `too-many-requests` | Too many attempts. Please try again later. |
| `network-request-failed` | Network error. Check your connection and try again. |

---

## OTP API

### `OtpApi` (Abstract)
**File:** `lib/services/otp_api.dart`

Handles all OTP operations via Firebase Cloud Functions (or REST fallback).

#### Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `sendSignupOtp` | `email` | Send 6-digit verification code for new signup |
| `verifySignupOtp` | `email`, `otp` | Verify signup OTP and mark email verified |
| `sendPasswordResetOtp` | `email` | Send reset code for forgotten password |
| `verifyPasswordResetOtp` | `email`, `otp` | Verify reset OTP |
| `sendChangePasswordOtp` | `email` | Send OTP for authenticated password change |
| `verifyChangePasswordOtp` | `email`, `otp` | Verify change-password OTP |
| `changePassword` | `email`, `otp`, `newPassword` | Apply new password (change flow) |
| `resetPassword` | `email`, `otp`, `newPassword` | Apply new password (reset flow) |

#### Cloud Functions Called
| Function Name | Parameters | Description |
|---------------|-----------|-------------|
| `sendSignupOtp` | `{email}` | Triggers OTP email for signup |
| `verifySignupOtp` | `{email, otp}` | Validates OTP, marks user verified |
| `sendPasswordResetOtp` | `{email}` | Triggers OTP email for reset |
| `verifyPasswordResetOtp` | `{email, otp}` | Validates reset OTP |
| `sendChangePasswordOtp` | `{email}` | Triggers OTP for password change |
| `verifyChangePasswordOtp` | `{email, otp}` | Validates change-password OTP |
| `changePassword` | `{email, otp, newPassword}` | Updates password in Firebase |
| `resetPassword` | `{email, otp, newPassword}` | Updates password in Firebase |

#### Platform Support
| Platform | Method | Notes |
|----------|--------|-------|
| Android | Cloud Functions SDK | Native plugin |
| iOS | Cloud Functions SDK | Native plugin |
| macOS | Cloud Functions SDK | Native plugin |
| Web | Cloud Functions SDK | JS interop |
| Windows | REST API fallback | HTTP POST to `https://us-central1-{project}.cloudfunctions.net/{name}` |
| Linux | REST API fallback | HTTP POST to `https://us-central1-{project}.cloudfunctions.net/{name}` |

#### Error Handling
| Cloud Functions Code | HTTP Status | User Message |
|----------------------|------------|-------------|
| `not-found` | 404 | No account found with this email address. |
| `resource-exhausted` | 429 | Too many attempts. Please try again later. |
| `unavailable` | 503 | Service temporarily unavailable. Please try again. |
| `unauthenticated` | 401 | You are not signed in. |
| `PERMISSION_DENIED` | 403 | You can only change the password for your own account. |
| `DEADLINE_EXCEEDED` | 504 | This code has expired. Please request a new one. |

---

## Data API

### `ItemRepository`
**File:** `lib/data/firestore/item_repository.dart`

Firestore CRUD for the `items` collection.

#### Methods

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `newId` | — | `String` | Generate a new Firestore document ID |
| `addItem` | `LostFoundItem` | `Future<void>` | Create/update item document |
| `getItem` | `id` | `Future<LostFoundItem?>` | Fetch single item by ID |
| `streamItems` | `kind?` | `Stream<List<LostFoundItem>>` | Real-time stream of items (optionally filtered by kind) |
| `updateItem` | `LostFoundItem` | `Future<void>` | Update existing item |
| `deleteItem` | `id` | `Future<void>` | Delete item document |

#### Firestore Collection: `items`
| Field | Type | Description |
|-------|------|-------------|
| `kind` | `String` | `"lost"` or `"found"` |
| `title` | `String` | Item name |
| `description` | `String` | Color/description |
| `ownerUid` | `String` | UID of reporter |
| `location` | `String?` | Where lost/found |
| `storageLocation` | `String?` | Where found item is stored |
| `status` | `String` | `"open"`, `"matched"`, or `"closed"` |
| `media` | `List<String>` | Photo download URLs |
| `createdAt` | `DateTime` | Creation timestamp |
| `updatedAt` | `DateTime` | Last update timestamp |

### `DatabaseService`
**File:** `lib/data/firestore/database_service.dart`

Generic Firestore CRUD for `items` and `users` collections. Returns maps with the document `id` merged in. Throws `DatabaseException` on failure; injectable `FirebaseFirestore` for testing.

#### Items Methods

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `reportItem` | `itemName`, `description`, `userId`, `status`, `imageUrl?`, `location?` | `Future<String>` | Save a report, returns doc ID (`imageUrl` defaults to placeholder) |
| `streamItems` | `status?` | `Stream<List<Map<String, dynamic>>>` | Live stream, optionally filtered by status |
| `getItem` | `itemId` | `Future<Map<String, dynamic>?>` | Fetch single item by ID |
| `updateItem` | `itemId`, `data` | `Future<void>` | Merge-update fields |
| `deleteItem` | `itemId` | `Future<void>` | Delete item doc |

#### User Profile Methods

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `createUserProfile` | `uid`, `email`, `displayName?`, `role` (`'user'`) | `Future<void>` | Set profile with `SetOptions(merge: true)` |
| `getUserProfile` | `uid` | `Future<Map<String, dynamic>?>` | Fetch profile by UID |
| `updateUserProfile` | `uid`, `data` | `Future<void>` | Merge-update profile fields |

#### `DatabaseException`
```dart
class DatabaseException implements Exception {
  const DatabaseException(this.message, {this.code});
  final String message;
  final String? code;
}
```

### `StorageService`
**File:** `lib/data/storage/storage_service.dart`

Firebase Storage uploads for item photos.

#### Methods

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `uploadItemPhotos` | `itemId`, `images` | `Future<List<String>>` | Upload photos, return download URLs |

#### Storage Structure
```
items/
  {itemId}/
    {timestamp}_0.jpg
    {timestamp}_1.jpg
    ...
```

---

## Chatbot API

### `KashtepChatService`
**File:** `lib/services/kashtep_chat_service.dart`

Direct Gemini API client (no Cloud Function proxy). Uses the API key from `.env` (`GEMINI_API_KEY`). Model: `gemini-2.0-flash`.

#### `ChatMessage`
```dart
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime? timestamp;
}
```

#### Methods

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `history` | — | `List<ChatMessage>` | Unmodifiable in-memory conversation history |
| `clearHistory` | — | `void` | Reset conversation |
| `addUserMessage` | `message` | `void` | Add a user message to history (for immediate UI display) |
| `sendMessage` | `message` | `Future<String>` | Send to Gemini, return assistant text |

#### Behaviors
- Sends the last 20 messages (full history) as `contents` plus a `systemInstruction` constraining KashTeP to app-related answers.
- Timeout: 30s per request; `temperature: 0.4`, `maxOutputTokens: 500`.
- Handles blocked prompts (`blockReason` / `finishReason == 'SAFETY'`) with friendly messages.
- HTTP 429 → rate-limit message; other errors → API error message fallback.
- SECURITY NOTE: API key is exposed in the client binary. Fine for prototyping/school; move to a backend proxy for production.

### `ChatService` (Legacy)
**File:** `lib/services/chat_service.dart`

Original direct-Gemini client used by `ChatbotButton`/`ChatScreen`. Superseded by `KashtepChatService` but kept for compatibility.

---

## Data Models

### `LostFoundItem`
**File:** `lib/models/lost_found_item.dart`

| Field | Type | Required | Default |
|-------|------|----------|---------|
| `id` | `String` | Yes | — |
| `kind` | `ItemKind` | Yes | — |
| `title` | `String` | Yes | — |
| `description` | `String` | Yes | — |
| `ownerUid` | `String` | Yes | — |
| `location` | `String?` | No | `null` |
| `storageLocation` | `String?` | No | `null` |
| `status` | `ItemStatus` | No | `ItemStatus.open` |
| `media` | `List<String>` | No | `[]` |
| `createdAt` | `DateTime?` | No | `null` |
| `updatedAt` | `DateTime?` | No | `null` |

#### Enums
```dart
enum ItemKind { lost, found }
enum ItemStatus { open, matched, closed }
```

### `UserProfile`
**File:** `lib/models/user_profile.dart`

| Field | Type | Required |
|-------|------|----------|
| `uid` | `String` | Yes |
| `displayName` | `String` | Yes |
| `email` | `String?` | No |
| `photoUrl` | `String?` | No |
| `fcmTokens` | `List<String>` | No (default `[]`) |
| `createdAt` | `DateTime?` | No |
| `updatedAt` | `DateTime?` | No |

### `AppMessage`
**File:** `lib/models/app_message.dart`

| Field | Type | Required |
|-------|------|----------|
| `id` | `String?` | No |
| `itemId` | `String` | Yes |
| `senderUid` | `String` | Yes |
| `receiverUid` | `String` | Yes |
| `text` | `String` | Yes |
| `read` | `bool?` | No (default `false`) |
| `createdAt` | `DateTime?` | No |

---

## Validators API
**File:** `lib/utils/validators.dart`

| Method | Input | Returns | Rule |
|--------|-------|---------|------|
| `email` | `String?` | `String?` | Required, valid email format |
| `loginPassword` | `String?` | `String?` | Required (light validation) |
| `fullName` | `String?` | `String?` | Required, min 2 chars, must contain letters |
| `password` | `String?` | `String?` | Required, 8+ chars, uppercase, lowercase, number |
| `confirmPassword` | `String?`, `String?` | `String?` | Required, must match original |
| `otp` | `String?` | `String?` | Required, exactly 6 digits |
| `passwordStrength` | `String` | `int` | Score 0-4 (length, uppercase, number, symbol) |
