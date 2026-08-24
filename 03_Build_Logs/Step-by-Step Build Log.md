# App Build Log: AmongApp (KAH KEN SHA NEY)

## 2025-08-07 - Project Initialization
* **Flutter Version:** ^3.12.2 (Dart SDK)
* **Architecture:** Feature-based (screens, pages, widgets, services, models, data)
* **State Management:** setState (local state) + Streams (Firestore real-time)
* **Backend:** Firebase (Auth, Firestore, Storage, Cloud Functions, Messaging)
* **Packages Installed:**
  * `firebase_core: ^4.12.1` — Firebase initialization
  * `firebase_auth: ^6.5.6` — User authentication
  * `cloud_firestore: ^6.8.0` — Firestore database
  * `firebase_storage: ^13.4.6` — File/image storage
  * `firebase_messaging: ^16.5.0` — Push notifications
  * `cloud_functions: ^6.3.5` — Cloud Functions (OTP API)
  * `http: ^1.2.0` — REST API calls (fallback for Cloud Functions)
  * `image_picker: ^1.2.3` — Camera/gallery image selection
  * `flutter_lints: ^6.0.0` — Lint rules (dev)

### Steps Executed Today:
1. Initialized Flutter project structure.
2. Configured `pubspec.yaml` dependencies.
3. Created folder hierarchy: `models/`, `screens/`, `pages/`, `widgets/`, `services/`, `data/`, `utils/`, `theme/`.
4. Set up Firebase configuration (`firebase_options.dart`).
5. Implemented authentication flow (Login, Signup, OTP, Forgot Password, Change Password).
6. Built core UI: MainPage, Dashboard, HomeFeed, Profile, Messages.
7. Created item reporting system (Report Lost, Submit Found).
8. Added AI Scan page (camera placeholder with scanning animation).
9. Implemented Firestore data layer (`ItemRepository`, `StorageService`).
10. Built reusable widget library (27 widgets).

### Obstacles / Bugs Encountered:
* *Issue:* Gradle build failure on initial Android sync.
* *Fix:* Updated Kotlin version in `android/build.gradle.kts` (Kotlin DSL).

---

## 2025-08-07 - KashTeP Chatbot Integration (Direct Gemini API)
* **API Configured:** Google AI Studio (Gemini 2.0 Flash) — FREE tier
* **Scope:** App details and instruction helper (KashTeP).
* **Architecture:** Direct API calls from Flutter client (no Cloud Function proxy).
* **Security (Temporary Tradeoff):** API key stored in `.env` via `flutter_dotenv`. Exposed in client binary — acceptable for testing, prototyping, and school projects. For production: migrate to backend proxy (Firebase Functions on Blaze plan, Flask, Node.js, etc.).
* **Rate Limiting:** Client-side request throttling (30s timeout per request).
* **Chat History:** Maintained in-memory during session, last 20 messages sent for context.

### Steps Executed Today:
1. Added `flutter_dotenv: ^5.2.1` to `pubspec.yaml`.
2. Created `.env` with `GEMINI_API_KEY` (direct client call).
3. Created `.env.example` for Flutter.
4. Updated `main.dart` to load `.env` via `dotenv.load()`.
5. Created `lib/services/chat_service.dart` — Direct Gemini REST API client with conversation history and system instruction.
6. Created `lib/widgets/chatbot.dart` — Floating button + bottom sheet chat UI with typing animation, quick chips, and message bubbles.
7. Integrated `ChatbotButton` into `DashboardScreen` Stack.
8. Chatbot named "KashTeP" — only answers app feature questions, politely declines unrelated queries.

### Files Created/Modified:
* `pubspec.yaml` — Modified (added `flutter_dotenv`, `.env` asset)
* `lib/main.dart` — Modified (added `dotenv.load()`)
* `lib/services/chat_service.dart` — **NEW** (direct Gemini API client)
* `lib/widgets/chatbot.dart` — **NEW** (UI components)
* `lib/screens/dashboard.dart` — Modified (added `ChatbotButton`)
* `.env` — **NEW** (API key for direct client use)
* `.env.example` — **NEW** (template)
* `functions/src/chatbot.js` — **DEFERRED** (Cloud Function proxy — requires Blaze plan upgrade)
* `functions/index.js` — Modified (kashtep export — pending deployment)

---

## 2025-08-07 - Lost/Found 2-Column Grid Layout
Replaced the single-column list on the Lost and Found tabs with a 2-column card grid.

### Steps Executed:
1. Created `lib/widgets/item_grid_card.dart` — reusable grid card with network image + placeholder fallback, item name, truncated description, location, and status pill.
2. Created `lib/pages/items_grid_page.dart` — full grid page using a `CustomScrollView` + `SliverGrid` (2 columns, `SliverGridDelegateWithFixedCrossAxisCount`), gradient banner header with CTA button, and loading/error/empty states.
3. Updated `lib/pages/home_page.dart` — Lost tab now renders `ItemsGridPage(kind: lost)` with "Report Lost Item" banner → `/report-lost`; Found tab renders `ItemsGridPage(kind: found)` with "Found an Item?" banner → `/submit-found`.
4. `ItemRepository.streamItems(kind:)` streams from the `items` collection ordered by `createdAt` descending.

### Files Created/Modified:
* `lib/widgets/item_grid_card.dart` — **NEW**
* `lib/pages/items_grid_page.dart` — **NEW**
* `lib/pages/home_page.dart` — Modified (tabs → `ItemsGridPage`)

---

## 2025-08-07 - Modern Navigation Animations
Replaced the default bottom-nav/page transitions with smooth, direction-aware Material-motion style animations.

### Bottom Nav (`lib/widgets/bottom_nav.dart`)
* **Sliding pill indicator** — `TweenAnimationBuilder` glides the active-tab pill to the new position (350ms, `easeOutCubic`); position computed from `LayoutBuilder` + tab width.
* **Icon animation** — scale 0.92 → 1.0 on select, size 22 → 24, color lerp `textTertiary` → `primary`, outline→filled icon swap at the 50% midpoint.
* **Label fade** — `Opacity` fades labels in/out; haptic `mediumImpact()` on tap retained.
* No `AnimationController` — `TweenAnimationBuilder` handles lifecycle automatically.

### Page Transitions (`lib/widgets/tab_switcher.dart`)
* **Direction-aware slide** — 80px horizontal offset whose sign follows the navigation direction (forward → slide left, back → slide right).
* **Fade** — opacity 1 → 0 based on `abs(pageOffset)`.
* **Scale** — incoming 0.96 → 1.0 for depth.
* All three driven from the same `PageController.page` so they stay in sync at 60fps.

### Footer Sizing (tunings requested)
* Height reduced 72 → 56 → **60**; bottom safe-area `10` → `6` → `16`; icons enlarged 20 → **22→24**.

### Files Modified:
* `lib/widgets/bottom_nav.dart` — Rewritten
* `lib/widgets/tab_switcher.dart` — Rewritten

---

## 2026-08-19 - Branding, Dashboard Features & Reliability
Covers the KAH KEN SHA NEY rebrand, the user dashboard upgrade (live status tracking, real recent reports, account logout), the photo gallery feature, and chatbot reliability hardening.

### KAH KEN SHA NEY Branding
* Replaced all user-facing "AmongApp" references with **KAH KEN SHA NEY** ("an AI and ML-powered application that turns your lost into found"):
  * `lib/main.dart` — MaterialApp `title` (both firebase-ready and error routes).
  * `lib/services/chat_service.dart` + `lib/services/kashtep_chat_service.dart` + `functions/src/chatbot.js` — system prompts and developer information ("KAH KEN SHA NEY was developed by Melvin Maquilan, Cristian Jim Pogoy, Axl Moraleja, and Aldrian Dajes. They are 3rd-year BSCS students at SMCTI.").
* Technical identifiers keep `AmongApp` (project/package/folder names, `AmongApp` widget class, tests).

### Dashboard: Status Tracking + Recent Reports (`lib/pages/home_feed.dart`)
* `ItemStatus` extended from 3 → 6 stages in `lib/models/lost_found_item.dart`: `open` (Submitted) → `pendingVerification` → `verified` → `matched` → `claimed` → `closed` (Archived). Legacy values preserved so existing Firestore documents and admin tests keep working. Added `label` (tracker) and `shortLabel` (compact pill) via `ItemStatusX`.
* All exhaustive status switches updated for the 6 stages: `_StatusPill` in `lib/pages/item_list_page.dart` and `lib/widgets/item_grid_card.dart`, plus admin `_statusLabel`/`_StatusBadge` in `lib/screens/admin_dashboard.dart` (open still renders "Pending" for the admin test).
* `ItemRepository.streamUserItems(ownerUid)` (`lib/data/firestore/item_repository.dart`) — real-time per-user stream using only a single-field `ownerUid` query with a client-side `createdAt` desc sort (avoids a new composite index in the console).
* New `_UserReportsSection` widget in `home_feed.dart`:
  * **Status Tracking** — horizontally scrollable 6-step stepper (done/current/upcoming states, per-stage icons, connecting line). `Archived` renders as the fully-completed state.
  * **Recent Reports** — real Firestore rows (type icon, name, relative date, compact status pill), newest first, max 5 shown, tap to select (radio indicator) → tracker follows; data updates live via the stream.
  * **"View All Reports"** button → Reports tab (`onTabSelected(2)`).
  * Clean loading / error (with Retry that re-subscribes) / empty states. If no `ownerUid`, no Firestore query is made (keeps widget tests Firebase-free).
* `HomePage` and `DashboardScreen` now thread `ownerUid` (`_auth.currentUser?.uid`) and logout/change-password callbacks down to `HomeFeed`.

### User Logout
* Avatar now opens an account bottom sheet (Profile, Change Password, Log out).
* Log out shows a confirmation dialog, then `DashboardScreen._signOut()` signs out and `pushAndRemoveUntil` to `LoginScreen` (back button cannot return to the dashboard). Admin logout unchanged.

### Photo Gallery Feature
* `StorageService.uploadItemPhotos` now takes a required `folder` — report_lost writes to `lost/{itemId}/`, submit_found to `found/{itemId}/`.
* `StorageService.fetchImagesFromFolder(folderName)` recursively lists and resolves image download URLs.
* New `lib/pages/image_gallery_page.dart` — Lost/Found tabs, responsive 2/3/4-column grid, loading/empty/error+Retry, pull-to-refresh, image loading/error placeholders.
* `lib/pages/items_grid_page.dart` banner gains a "photo library" button that opens `ImageGalleryPage`.
* Old `items/{itemId}/` uploads still render via their Firestore download URLs.

### Chatbot Reliability
* `lib/services/chat_service.dart` rewritten — 60s configurable timeout, fresh `http.Client` per request (closed on completion unless injected) to avoid stale keep-alive stalls; `_buildContents` merges consecutive same-role turns and guarantees the current user message appears exactly once last; response parsing hardened (blocked prompts, empty candidates, SAFETY/BLOCKED finish reasons); explicit brief-and-complete developer answer instruction; `maxOutputTokens` 500 → 2048.
* Logs no longer include the API key or request URL (only "key configured: bool", message count, status, parse success).
* `lib/services/kashtep_chat_service.dart` and `functions/src/chatbot.js` — same developer/brief-answer instruction and `maxOutputTokens` 2048; `chatbot.js` model upgraded to `gemini-3.6-flash` (requires `firebase deploy --only functions`).
* `android/app/src/main/AndroidManifest.xml` — added `android:enableOnBackInvokedCallback="true"`.

### Verification
* `flutter analyze` — clean.
* `flutter test` — 61/61 pass (incl. admin "Pending" assertion and the narrow-screen Home feed overflow test).
* `flutter build apk --debug` — succeeds.

---

## Environment Details

| Property | Value |
|----------|-------|
| Project Name | amongapp |
| Version | 1.0.0+1 |
| Min SDK | Dart ^3.12.2 |
| Firebase Project | firstfirebase-5880d |
| Android App ID | 1:584709649247:android:61837035cf17c6af62bcea |

## Firebase Services Used
- **Authentication** — Email/password + OTP verification
- **Cloud Firestore** — Items, user profiles, messages
- **Firebase Storage** — Item photos (`lost/{itemId}/...`, `found/{itemId}/...`)
- **Cloud Functions** — OTP API (send/verify/change password)
- **Firebase Messaging** — Push notifications (FCM tokens stored in UserProfile)

## Project Structure
```
lib/
├── main.dart                 # App entry point
├── mainpage.dart             # Landing page
├── firebase_options.dart     # Firebase config (FlutterFire CLI)
├── data/
│   ├── firestore/item_repository.dart   # Typed Firestore CRUD for items
│   ├── firestore/database_service.dart  # Generic CRUD (items + users)
│   └── storage/storage_service.dart     # Firebase Storage uploads
├── models/
│   ├── lost_found_item.dart  # LostFoundItem, ItemKind, ItemStatus
│   ├── user_profile.dart     # UserProfile model
│   └── app_message.dart      # AppMessage model
├── pages/                    # Tab content & feature pages
│   ├── home_page.dart        # Nav shell (PageView + BottomNav)
│   ├── home_feed.dart        # Dashboard feed
│   ├── items_grid_page.dart  # 2-column Lost/Found grid
│   ├── item_list_page.dart   # Legacy list layout
│   └── ...
├── screens/auth/             # Auth flow screens
├── services/
│   ├── auth_service.dart     # AuthService abstract + FirebaseAuthService
│   ├── otp_api.dart          # OtpApi abstract + FirebaseOtpApi
│   ├── chat_service.dart     # Legacy direct Gemini client
│   └── kashtep_chat_service.dart # KashTeP direct Gemini client
├── theme/app_theme.dart      # AppColors + buildAppTheme()
├── utils/                    # Validators, transitions, cooldown timer
└── widgets/                  # Reusable UI components (incl. item_grid_card)
```
