# Development Status — Lost & Found App

**Last updated:** 2026-08-24 (latest session)
**Previous sessions:** 2026-08-22, 2026-08-23
**Overall:** OTP, Lost & Found, admin moderation, 1-on-1 chat, notifications, skeleton chatbot animation, FCM push trigger, and storage rules are implemented. Firestore indexes deployed. App builds and runs.

---

## Session 2026-08-24 — What Was Done

### 1. Firestore Security Rules — `DEPLOYED` ✅

**File:** `firestore.rules`

- **`isAdmin()` helper** — checks `users/{uid}.data.isAdmin == true`, guarded with `exists()` so it doesn't crash if user doc is missing
- **`items`** — read (approved/owner/admin), create (auth + ownerUid match), update (admin full access, owner limited), delete (owner/admin)
- **`users`** — read (auth), create (self), update (self/admin), delete (none)
- **`users/{uid}/notifications`** — read (self/admin), create (admin only), update (self for mark-read), delete (none)
- **`chats/{chatId}`** — read/create/update (self or admin), messages subcollection with senderId check
- **Key fix:** Removed strict `hasAll` key requirement on item create — was causing `PERMISSION_DENIED` because Firestore SDK strips null-valued keys

**Deployed:** ✅ `firebase deploy --only firestore:rules`

### 2. Firestore Composite Indexes — `DEPLOYED` ✅

**File:** `firestore.indexes.json`

| Collection | Fields | Purpose |
|-----------|--------|---------|
| `items` | `kind` ASC + `createdAt` DESC | Public browse (Lost/Found tabs) |
| `items` | `status` ASC + `createdAt` DESC | Filter by status |
| `items` | `moderationStatus` ASC + `createdAt` DESC | Admin pending queue |
| `items` | `kind` ASC + `moderationStatus` ASC + `createdAt` DESC | Public browse filtered by kind |
| `items` | `ownerUid` ASC + `createdAt` DESC | User's reports |
| `notifications` | `isRead` ASC + `createdAt` DESC | User notifications |

**Deployed:** ✅ `firebase deploy --only firestore:indexes`

### 3. Storage Rules — `DEPLOYED` ✅

**File:** `storage.rules`

- Authenticated users can read all, write to `lost_and_found/` with size/type limits

**Deployed:** ✅ `firebase deploy --only storage`

### 4. ModerationStatus System — `IMPLEMENTED` ✅

**File:** `lib/models/lost_found_item.dart`

```dart
enum ModerationStatus { pending, approved, rejected }

class LostFoundItem {
  final ModerationStatus moderationStatus;  // defaults to 'pending'
  final List<StatusHistoryEntry> statusHistory;  // log of all status changes
  final String? matchedItemId;
  // ... existing fields
}
```

### 5. ItemRepository — `UPDATED` ✅

**File:** `lib/data/firestore/item_repository.dart`

- `streamItems()` — filters `moderationStatus == 'approved'` (with error fallback)
- `streamPendingItems()` — admin pending queue
- `streamAllItemsForAdmin()` — admin sees everything
- `streamItemsWithSearch()` — client-side search
- `streamUserItems()` — user's own reports
- `updateItemFields()` — partial updates
- **Error handling:** All streams use `.handleError()` to prevent crashes if indexes are missing

### 6. Admin Review Queue — `IMPLEMENTED` ✅

**File:** `lib/screens/admin_review_queue_screen.dart`

- Lists items with `moderationStatus == 'pending'`
- Approve/Reject buttons per item
- StatusTrackerWidget integration
- Full status controls in bottom sheet

### 7. User Reports Screen — `IMPLEMENTED` ✅

**File:** `lib/screens/user_reports_screen.dart`

- Shows user's own items with moderation status badges
- Tap to view StatusTrackerWidget
- Color-coded badges (pending=orange, approved=green, rejected=red)

### 8. StatusTrackerWidget — `IMPLEMENTED` ✅

**File:** `lib/widgets/status_tracker_widget.dart`

- Horizontal stepper UI
- Steps: Submitted → Pending Verification → Verified → Matched → Claimed → Archived
- Compact mode available
- Shows history of status changes with timestamps

### 9. NotificationService (Firestore-based) — `IMPLEMENTED` ✅

**File:** `lib/data/firestore/notification_service.dart`

- `AppNotification` model (title, body, isRead, type, relatedItemId, createdAt)
- CRUD: `createNotification()`, `markAsRead()`, `markAllAsRead()`
- Streams: `streamUserNotifications()`, `unreadCountStream()`
- Helper methods: `notifyModerationChange()`, `notifyStatusChange()`

### 10. Notifications Screen — `IMPLEMENTED` ✅

**File:** `lib/screens/notifications_screen.dart`

- Lists user's notifications with icons and relative timestamps
- Mark all as read button
- Empty state with icon

### 11. Support Chat System (1-on-1) — `IMPLEMENTED` ✅

**Models:**
- `lib/models/support_chat.dart` — chat document with participants, lastMessage, lastMessageAt
- `lib/models/support_message.dart` — message subcollection with senderId, text, timestamp

**Service:** `lib/data/firestore/support_chat_service.dart`
- `sendMessage()`, `streamMessages()`, `streamAllChats()`
- `markReadByAdmin()`, `markReadByUser()`, `getUserDisplayName()`

**Screens:**
- `lib/screens/user_chat_screen.dart` — user-facing chat (blue right, gray left bubbles)
- `lib/screens/admin_chat_detail_screen.dart` — admin replies to user
- `lib/screens/admin_inbox_screen.dart` — lists all user chats

**Wired into:**
- `lib/pages/messages_page.dart` — replaced placeholder with `UserChatScreen`
- `lib/screens/admin_dashboard.dart` — sidebar has Messages (index 6) → `AdminInboxScreen`

### 12. Cloud Functions (FCM + Migration) — `DEPLOYED` ✅

**File:** `functions/src/index.ts`

| Function | Type | Region | Purpose |
|----------|------|--------|---------|
| `sendPushNotification` | Firestore trigger (`onDocumentCreated`) | us-central1 | Sends FCM multicast when notification doc is created |
| `migrateModerationStatus` | Callable | us-central1 | One-time migration to add `moderationStatus: 'approved'` to all existing items |

**Key fix:** `package.json` changed `"main": "index.js"` → `"main": "lib/index.js"` to match tsconfig output directory. This was why new functions weren't being deployed.

### 13. Chatbot Skeleton Animation — `IMPLEMENTED` ✅

**File:** `lib/widgets/chatbot.dart`

- Replaced 3-dot typing indicator with shimmer skeleton animation
- Uses `ShaderMask` + `LinearGradient` with `AnimationController`
- Two skeleton bubbles (left/right) that pulse while bot is "thinking"

### 14. Admin Dashboard — `UPDATED` ✅

**File:** `lib/screens/admin_dashboard.dart`

- Sidebar sections: Dashboard (0), Review Queue (1), Lost Items (2), Found Items (3), Reports (4), Users (5), Messages (6), Settings (7), Logout (8)
- Settings section has "Run Moderation Migration" button
- `_buildSectionBody()` handles cases 0, 1, 6, 7

### 15. Bug Fixes This Session

| Issue | Fix |
|-------|-----|
| `ascending: true` not a Firestore parameter | Removed `ascending` param (default is ascending) in `item_repository.dart` and `support_chat_service.dart` |
| `AppColors` not const | Added missing `AppColors` import in `messages_page.dart`, removed `const` from non-const constructors |
| App crash on startup (PERMISSION_DENIED) | `isAdmin()` function crashed when user doc didn't exist — added `exists()` guard |
| Item create PERMISSION_DENIED | Removed strict `hasAll` key check — Firestore strips null-valued keys |
| Cloud Functions not deploying new functions | `package.json` had `"main": "index.js"` but tsconfig outputs to `lib/` |
| `sendPushNotification` deploy failed (Eventarc) | Added `{ region: 'us-central1' }` to `onDocumentCreated` options |

---

## Cloud Functions (Full List) — `ALL DEPLOYED` ✅

| Function | Trigger | Region |
|----------|---------|--------|
| `sendSignupOtp` | `onCall` | us-central1 |
| `verifySignupOtp` | `onCall` | us-central1 |
| `sendPasswordResetOtp` | `onCall` | us-central1 |
| `verifyPasswordResetOtp` | `onCall` | us-central1 |
| `sendChangePasswordOtp` | `onCall` | us-central1 |
| `verifyChangePasswordOtp` | `onCall` | us-central1 |
| `changePassword` | `onCall` | us-central1 |
| `resetPassword` | `onCall` | us-central1 |
| `kashtep` | `onCall` | us-central1 |
| `sendPushNotification` | Firestore trigger | us-central1 |
| `migrateModerationStatus` | `onCall` | us-central1 |

---

## Firebase Project Config

| Field | Value |
|-------|-------|
| Project ID | `firstfirebase-5880d` |
| Project number | `584709649247` |
| Storage bucket | `firstfirebase-5880d.firebasestorage.app` |
| Android package | `com.kahkenshaney.amongapp` |
| Admin email | `mugiwaranomelvin@gmail.com` |
| Admin UID constant | `lib/services/auth_service.dart` → `kAdminUid = 'REPLACE_WITH_ADMIN_UID'` (**MUST UPDATE**) |

---

## TODO — Next Session (2026-08-25)

### Priority 1: Migration + Admin Setup (do first)

- [ ] **Run migration:** Tap "Run Moderation Migration" in admin Settings → adds `moderationStatus: 'approved'` to all existing items
- [ ] **Update `kAdminUid`:** Get actual admin Firebase Auth UID from console → paste into `lib/services/auth_service.dart`
- [ ] **Verify `isAdmin` field:** Ensure admin user's Firestore `users/{uid}` doc has `isAdmin: true`
- [ ] **Test item creation:** Submit a lost/found report → verify it saves and appears in admin queue as `pending`

### Priority 2: Notifications System

- [ ] **Save FCM token to user profile:** In login/auth flow, save FCM token to `users/{uid}.fcmTokens` array
- [ ] **Token refresh:** Listen to `onTokenRefresh` and update Firestore
- [ ] **In-app notification banner:** Show local notification when app is in foreground
- [ ] **Test:** Create item → admin approves → user gets notification in notifications screen + push notification on device

### Priority 3: Admin ↔ User Chat

- [ ] **Test chat flow:** User taps chat icon → opens `UserChatScreen` → sends message → admin sees in `AdminInboxScreen` → admin replies
- [ ] **Real-time sync:** Messages stream in real-time between user and admin
- [ ] **Unread badges:** Show unread count on chat icon / admin inbox
- [ ] **Last message preview:** Show last message text and timestamp in admin inbox list

### Priority 4: Image Gallery & Details

- [ ] **Item detail screen:** Show all images from `media` array in a swipeable gallery (PageView)
- [ ] **Full-screen image viewer:** Tap image → open full-screen with pinch-to-zoom
- [ ] **Image metadata:** Show file name, upload date, image dimensions (if available)
- [ ] **Lazy loading:** Use cached network images with placeholder shimmer
- [ ] **Multiple photos in grid:** Show all photos in item cards, not just primary

### Priority 5: Tracking Status Pipeline

- [ ] **Status transition flow:** Pending Verification → Verified → Matched → Claimed → Closed
- [ ] **User actions:** User can mark as "Found" or "Returned" from item detail
- [ ] **Status history:** StatusTrackerWidget shows full audit trail with timestamps and who changed it
- [ ] **Matched items:** When admin matches lost ↔ found, both items update status + link via `matchedItemId`

### Priority 6: Homepage Content

- [ ] **Design homepage:** What should it show?
  - Option A: Recent items feed (lost + found mixed, newest first)
  - Option B: Dashboard with stats (total items, pending, resolved)
  - Option C: Category cards (Lost, Found, Recently Matched) + search bar
  - Option D: Map view with item locations
- [ ] **Quick actions:** Report Lost / Report Found buttons prominently placed
- [ ] **Search:** Global search across all approved items
- [ ] **Pull-to-refresh:** Refresh feed on pull

### Priority 7: Polish & Deployment

- [ ] **Error states:** Empty states, network error handling, loading skeletons
- [ ] **Image compression:** Compress before upload to save storage/bandwidth
- [ ] **App Check:** Configure Firebase App Check to stop placeholder token warnings
- [ ] **Node.js upgrade:** Migrate Cloud Functions from Node.js 20 (deprecated) to Node.js 22
- [ ] **Production rules:** Tighten security rules for production (e.g., rate limiting, field validation)

---

## Key File Index

| Category | Files |
|----------|-------|
| **Models** | `lib/models/lost_found_item.dart`, `lib/models/support_chat.dart`, `lib/models/support_message.dart` |
| **Data layer** | `lib/data/firestore/item_repository.dart`, `lib/data/firestore/admin_repository.dart`, `lib/data/firestore/database_service.dart`, `lib/data/firestore/notification_service.dart`, `lib/data/firestore/support_chat_service.dart` |
| **Storage** | `lib/data/storage/storage_service.dart` |
| **Services** | `lib/services/auth_service.dart`, `lib/services/notification_service.dart` (FCM) |
| **Admin screens** | `lib/screens/admin_dashboard.dart`, `lib/screens/admin_review_queue_screen.dart`, `lib/screens/admin_inbox_screen.dart`, `lib/screens/admin_chat_detail_screen.dart` |
| **User screens** | `lib/screens/user_reports_screen.dart`, `lib/screens/user_chat_screen.dart`, `lib/screens/notifications_screen.dart` |
| **Pages** | `lib/pages/browse_items_page.dart`, `lib/pages/messages_page.dart`, `lib/pages/report_lost_page.dart`, `lib/pages/submit_found_page.dart` |
| **Widgets** | `lib/widgets/status_tracker_widget.dart`, `lib/widgets/chatbot.dart`, `lib/widgets/item_grid_card.dart` |
| **Cloud Functions** | `functions/src/index.ts` |
| **Security** | `firestore.rules`, `firestore.indexes.json`, `storage.rules` |
| **Config** | `firebase.json`, `functions/package.json`, `functions/tsconfig.json` |

---

## Build & Deploy Commands

```bash
# Build & install debug APK
flutter build apk --debug
flutter install --debug

# Deploy everything
firebase deploy --only firestore:rules,firestore:indexes,storage,functions

# Deploy individually
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
firebase deploy --only functions

# Rebuild Cloud Functions
cd functions && npm run build && cd ..
firebase deploy --only functions --force
```
