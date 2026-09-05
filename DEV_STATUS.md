# AmongApp Development Status

**Last Updated:** 2026-09-05
**Session Focus:** Essential app features audit + implementation (Settings, Account Deletion, Privacy Policy, Help & Support, Moderation/Report/Block services, Admin Dashboard polish, Notification refinements)
**Canonical session log:** `docs/development_status.md` (keep this file updated there)

---

## Session 2026-09-05 — Essential App Features + Bug Fixes

### Feature Audit & Implementation
- **Settings screen** (`lib/screens/settings_screen.dart`): Account management, notification preferences, legal pages, support, version display, logout, account deletion
- **Account deletion** (P0): Password reauth + type "DELETE" confirmation → Firebase Auth + Firestore user doc deletion
- **Privacy Policy** in-app screen (embedded in settings)
- **Help & Support / FAQ** with ExpansionTile accordions
- **Contact Support** form (subject + message → Firestore `supportMessages`)
- **Moderation service** (`lib/services/moderation_service.dart`): Report content, block/unblock users, notification preferences
- **Action progress bar** (`lib/widgets/action_progress_bar.dart`): Reusable animated bar replacing toasts for admin actions
- **Firestore rules** updated: `moderation_reports`, `blocked_users`, `preferences`, user self-deletion, notification creation
- **App Check** note added to rules (not yet configured — flagged for production)

### Bug Fixes (Original Tasks 1–9)
- Chatbot Firestore rules already correct; App Check comment added
- Chatbot quick questions simplified (removed "How do I report lost items?")
- Login snackbar "Enter your password to continue" removed
- Filter icon on home search bar now opens BrowseItemsPage
- Admin dashboard bell icon: unread notification badge
- Admin dashboard: FadeSlideIn entrance animations on all sections
- Notification list: blur on unread items, rounded corners, red dot indicator
- Admin review queue: ActionProgressBar replaces SnackBar toasts
- Item detail: claim notifications to reporter + admin; self-claim guard

### Test Fix
- `saved_accounts_test.dart`: Updated expectation to match removed snackbar

---

## Session 2026-09-04 — What Was Done

### New: Foreground Notification Banner
- **Files:** `lib/widgets/notification_banner.dart` (NEW), `lib/services/notification_service.dart`, `lib/screens/dashboard.dart`
- **How it works:**
  - `NotificationService.lastForegroundMessage` — static `ValueNotifier<RemoteMessage?>` set by the `onMessage` listener when a push arrives while the app is foregrounded
  - `NotificationBannerHost` — wraps the dashboard, listens to the notifier, slides an in-app banner in from the top (icon, title, body), auto-dismisses after 5s
  - Tap → opens the related item via `data.relatedItemId` (falls back to the Notifications screen)
- **Deploy note:** Requires FCM tokens on `users/{uid}.fcmTokens` (already saved by `NotificationService.initialize(userId:)` at `lib/screens/dashboard.dart`) and `sendPushNotification` Cloud Function deployed.

### Tech Debt Cleanup
- **Deleted `lib/services/kashtep_chat_service.dart`** — duplicate of `chat_service.dart` (ChatService), zero usages. `ChatService` remains the active chatbot backend (`lib/widgets/chatbot.dart`).
- **Deleted `lib/models/app_message.dart`** — zero usages.
- **Node.js 20 → 22** — `functions/package.json` `engines.node` updated. Run `cd functions && npm run build && firebase deploy --only functions` to deploy.

### Docs Sync
- `DEV_STATUS.md` (this file) and `README.md` updated to match actual code state — several items previously listed as placeholders/blockers are already implemented (see below).

---

## Previously Completed (Recent Highlights)

### Session 2026-08-26 (see `docs/development_status.md` for full log)
- RenderFlex overflow crash fixed (`home_feed.dart`, `mainAxisSize: MainAxisSize.min`)
- Item Details page: category info row, AI Match section, Mark as Resolved, related items
- `ItemRepository.streamPotentialMatches()` added
- Firestore rules: owner can set `status` to `claimed`

### Session 2026-09-04 (admin & polish, logged in `docs/development_status.md`)
- Admin sidebar auto-close fix; Review Queue instant removal on approve/reject; rejection reason dialog
- New admin "Resolved" section (`admin_resolved_screen.dart`); `ItemStatus.resolved` enum added
- Search bar moved to Browse page (`initialSearchQuery`); score-based related items
- Typography/typewriter animation speedups; signup text fix; badge overflow fix; darkened text colors

---

## Status of Formerly-Listed Blockers (RESOLVED)

| Former blocker | Status | How |
|---|---|---|
| `kAdminUid` placeholder (`REPLACE_WITH_ADMIN_UID`) | ✅ Resolved | Runtime `lookupAdminUid()` in `lib/services/auth_service.dart` queries `users` where `isAdmin == true`; `kAdminEmail` constant is the hardcoded fallback. Admin user doc must have `isAdmin: true`. |
| FCM tokens not saved | ✅ Resolved | `NotificationService.initialize(userId:)` saves token via `arrayUnion` + listens to `onTokenRefresh`. Wired at `lib/screens/dashboard.dart`. |
| Image gallery placeholder | ✅ Resolved | `lib/screens/item_detail_screen.dart` renders `media[]` thumbnails; `image_gallery_page.dart` is a full gallery screen |
| Profile editing placeholder | ✅ Resolved | `lib/screens/edit_profile_screen.dart` |
| Global search placeholder | ✅ Resolved | `lib/widgets/search_bar.dart` + `initialSearchQuery` on Browse page |
| Duplicate chat services | ✅ Resolved | `kashtep_chat_service.dart` deleted; `ChatService` is the single chatbot backend |

## Known Blockers / TODOs (REMAINING)

| Item | Status | Notes |
|---|---|---|
| Firestore rules / functions deployment | User action | `firebase deploy --only firestore:rules,functions` — local changes only until deployed |
| Foreground push test | Needs device test | Banner implemented; verify end-to-end with a real push (admin approves an item) |
| Admin doc `isAdmin: true` | Needs console check | `lookupAdminUid()` requires `users/{uid}.isAdmin == true` |
| Moderation migration | Needs manual run | "Run Moderation Migration" in admin Settings → adds `moderationStatus: 'approved'` to existing items |
| Admin inbox polish | Open | Unread badges + last-message preview in `admin_inbox_screen.dart` |
| Pull-to-refresh on grid pages | Open | Exists on browse page only |
| Empty states / error handling | Open | Polish pass |
| App Check | Open | Configure Firebase App Check |

---

## TODO for Tomorrow (2026-09-06)

| Bug | Status | Details |
|---|---|---|
| "Claim This Item" button not visible/found | **TO FIX** | Investigate why the claim button doesn't appear on item detail screen. Likely a `canBeClaimedBy()` logic issue — the button condition may be too restrictive or the item's `ownerUid` / `status` doesn't match the expected state. Trace `item_detail_screen.dart` → `LostFoundItem.canBeClaimedBy()` → `item.canBeClaimedBy(currentUid ?? '', isAdmin: isAdmin)` and verify all `ItemStatus` states where claiming should be allowed. |
| "Mark as Resolved" not visible/found | **TO FIX** | Investigate why the resolve button doesn't appear for admin. The `canResolve` guard is `!item.status.isTerminal && isAdmin`. Verify: (1) `isAdminEmail()` returns true for the logged-in admin, (2) the item status is not already terminal, (3) the item detail screen receives the correct admin state. Check `item_detail_screen.dart:76` and `isAdminEmail()` in `auth_service.dart`. |

---

## Key Architecture Notes

- **Item model fields:** `id`, `title`, `description`, `kind`, `status`, `moderationStatus`, `category`, `location`, `storageLocation`, `ownerUid`, `media[]`, `imageUrl`, `matchedItemId`, `createdAt`, `updatedAt`, `statusHistory[]`
- **ItemStatus lifecycle:** `open` → `pendingVerification` → `verified` → `matched` → `claimed` → `resolved` → `closed`
- **ModerationStatus:** `pending` → `approved` / `rejected` (with `rejectionReason`)
- **Chat system:** Admin support (`chats/{userId}`) via `SupportChatService` + chatbot via `ChatService` (Gemini direct API)
- **Push pipeline:** Firestore notification doc → `sendPushNotification` (Cloud Function) → FCM → foreground banner / system notification
- **Device:** Infinix X6528, `adb` at `C:\Users\Ventong\AppData\Local\Android\Sdk\platform-tools\adb.exe`
- **App package:** `com.kahkenshaney.amongapp`