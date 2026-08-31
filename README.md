# KAH KEN SHA NEY (AmongApp)

AI and ML-powered Lost & Found application that turns your lost into found, with OTP-based authentication.

---

## App Objectives

1. **Reunite People with Lost Items** — Provide a platform where users can report lost items and finders can submit found items, with AI-powered matching to connect them
2. **Campus/Community Safety** — Help institutions manage lost & found operations with admin moderation, status tracking, and real-time notifications
3. **Smart Matching** — Use AI to automatically match lost reports with found items based on category, description, and image similarity
4. **Secure Authentication** — OTP-based email verification for signup, password reset, and password change (no plain passwords)
5. **Real-time Communication** — Enable direct chat between finders and reporters to coordinate item return

---

## Current Status

**Last Updated:** 2026-08-26  
**Overall:** Core features implemented. App builds and runs. Some features are placeholder-only.

### Implemented Features

| Feature | Status | Notes |
|---------|--------|-------|
| **OTP Authentication** | Working | Email-based signup, login, password reset, change password |
| **Lost & Found Reports** | Working | Users can submit lost/found items with photos, category, location |
| **Admin Moderation** | Working | Admin review queue with approve/reject workflow |
| **Status Tracking** | Working | 6-stage tracker: Submitted → Pending Verification → Verified → Matched → Claimed → Archived |
| **Item Details** | Working | Hero image, metadata, category badge, AI match section, related items |
| **Contact Reporter** | Working | Peer-to-peer chat between finders and reporters |
| **Admin Dashboard** | Working | Real-time stats, charts, user management, review queue |
| **Notifications Screen** | Working | In-app notifications with mark-as-read |
| **Home Feed** | Working | Real Firestore stats, recently reported items, quick actions |
| **User Reports** | Working | Users can view their own reports with status badges |
| **Firestore Security Rules** | Deployed | Admin-only moderation, owner-limited updates |
| **Firestore Indexes** | Deployed | Composite indexes for efficient queries |
| **Storage Rules** | Deployed | Authenticated users can upload with size/type limits |
| **Cloud Functions** | Deployed | OTP delivery, FCM push notifications, moderation migration |

### Partially Implemented / Placeholder

| Feature | Status | Notes |
|---------|--------|-------|
| **AI Camera Scanner** | Placeholder | UI exists but no actual AI/Gemini integration |
| **Profile Editing** | Placeholder | Profile page shows info but no edit capability |
| **Notifications Access** | Broken | Home feed notification button shows "coming soon" snackbar |
| **Admin Sidebar Sections** | Placeholder | Lost Items, Found Items, Reports sections show placeholder |
| **Global Search** | Placeholder | Search bar exists but no functionality |
| **Pull-to-refresh** | Partial | Exists on browse page, missing on grid pages |

### Known Blockers

| Issue | Priority | Status |
|-------|----------|--------|
| `kAdminUid` placeholder (`REPLACE_WITH_ADMIN_UID`) | P0 | Must update with actual admin UID |
| Firestore rules not deployed (local changes) | P0 | Run `firebase deploy --only firestore:rules` |
| FCM tokens not saved to Firestore | P1 | Users won't receive push notifications |
| Duplicate chat services (`ChatService` + `KashtepChatService`) | P2 | Tech debt, should consolidate |

---

## Features To Be Added

### Priority 1: Critical (Must Fix)

1. **Update Admin UID** — Replace `kAdminUid` placeholder with actual Firebase Auth UID
2. **Deploy Firestore Rules** — Run `firebase deploy --only firestore:rules` to enable status updates
3. **Save FCM Tokens** — Store device tokens in `users/{uid}.fcmTokens` on login for push notifications
4. **Wire Notifications Screen** — Replace "coming soon" snackbar with actual navigation to `NotificationsScreen`

### Priority 2: Core Features

5. **AI Camera Scanner** — Integrate Gemini Vision API for real-time item recognition and matching
6. **Image Gallery** — Swipeable PageView for items with multiple photos, full-screen viewer with pinch-to-zoom
7. **Profile Editing** — Allow users to update display name and photo
8. **Global Search** — Implement real search across approved items by title, description, category

### Priority 3: Admin Features

9. **Admin Lost Items Section** — Show all lost items with filters (status, date, category)
10. **Admin Found Items Section** — Show all found items with filters
11. **Admin Reports Section** — Aggregated reports view with export capability
12. **Image Compression** — Compress before upload to save storage/bandwidth

### Priority 4: Polish & UX

13. **Pull-to-refresh** — Add to all grid/list pages
14. **Loading Skeletons** — Replace spinners with shimmer placeholders
15. **Empty States** — Better empty state illustrations and messaging
16. **Error Handling** — Graceful network error handling with retry options
17. **App Check** — Configure Firebase App Check to stop placeholder token warnings

### Priority 5: Tech Debt

18. **Merge Chat Services** — Remove legacy `ChatService`, standardize on `KashtepChatService`
19. **Remove Unused Models** — Clean up `AppMessage` model if not needed
20. **Node.js Upgrade** — Migrate Cloud Functions from Node.js 20 (deprecated) to Node.js 22

---

## Project Structure

```
lib/
  main.dart                  — App entry point with Firebase init
  mainpage.dart              — Public landing page
  firebase_options.dart      — Firebase configuration
  screens/
    dashboard.dart           — Authenticated home with welcome overlay
    admin_dashboard.dart     — Admin control center with sidebar
    admin_review_queue_screen.dart — Admin moderation queue
    admin_inbox_screen.dart  — Admin chat inbox
    admin_chat_detail_screen.dart — Admin reply to user
    item_detail_screen.dart  — Full item detail view
    notifications_screen.dart — In-app notifications
    user_chat_screen.dart    — User peer-to-peer chat
    user_reports_screen.dart — User's own reports
    auth/                    — Login, signup, OTP, password reset flows
  pages/
    home_feed.dart           — Home dashboard with real Firestore data
    home_page.dart           — Tab container with bottom nav
    browse_items_page.dart   — Browse lost/found items
    items_grid_page.dart     — Grid view of items
    reports_page.dart        — All approved reports with filters
    report_lost_page.dart    — Report lost item form
    submit_found_page.dart   — Submit found item form
    choose_action_page.dart  — Gateway before lost/found forms
    messages_page.dart       — User chat with admin
    profile_page.dart        — User profile (read-only)
    ai_scan_page.dart        — AI camera scanner (placeholder)
    image_gallery_page.dart  — Image gallery (placeholder)
    item_list_page.dart      — Item list view
  services/
    auth_service.dart        — Authentication abstraction + Firebase
    otp_api.dart             — OTP backend (Cloud Functions)
    chat_service.dart        — Legacy chat service (deprecated)
    kashtep_chat_service.dart — Active chat service
    notification_service.dart — FCM push notifications
  data/firestore/
    item_repository.dart     — Item CRUD + streams
    admin_repository.dart    — Admin data streams
    database_service.dart    — User profile management
    notification_service.dart — In-app notification CRUD
    support_chat_service.dart — Chat messaging
  models/
    lost_found_item.dart     — Item model with status/moderation enums
    user_profile.dart        — User profile model
    support_chat.dart        — Chat document model
    support_message.dart     — Message model
    app_message.dart         — Legacy message model (unused)
  widgets/                   — 30+ reusable UI components
  theme/app_theme.dart       — Design tokens and Material 3 theme
  utils/                     — Validators, cooldown timer, page transitions

functions/
  src/
    index.ts                 — Cloud Functions entry point
    otp.ts                   — OTP generation and hashing
    email.ts                 — SMTP email delivery
    validation.ts            — Server-side input validation
    templates.ts             — HTML email templates
```

---

## Firebase Configuration

| Field | Value |
|-------|-------|
| Project ID | `firstfirebase-5880d` |
| Project number | `584709649247` |
| Storage bucket | `firstfirebase-5880d.firebasestorage.app` |
| Android package | `com.kahkenshaney.amongapp` |
| Admin email | `mugiwaranomelvin@gmail.com` |

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

---

## Getting Started

### Prerequisites

- Flutter SDK 3.12.2 or later
- Dart SDK 3.12.2 or later
- Firebase project with Authentication and Cloud Functions enabled
- SMTP server for email delivery

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd amongapp

# Install dependencies
flutter pub get

# Configure Firebase
dart pub global activate flutterfire_cli
flutterfire configure

# Run the app
flutter run
```

---

## License

Private — All rights reserved.
