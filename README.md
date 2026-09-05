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

**Last Updated:** 2026-09-04  
**Overall:** Core features implemented. App builds and runs. Push notifications (with in-app banner), search, profile editing, and image gallery all working. A few features remain placeholder-only.  
**Session log:** See `docs/development_status.md` and `DEV_STATUS.md` for detailed per-session progress.

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
| **Push Notifications** | Working | FCM tokens saved on login + refresh; foreground in-app banner; tap-through to item |
| **Home Feed** | Working | Real Firestore stats, recently reported items, quick actions |
| **User Reports** | Working | Users can view their own reports with status badges |
| **Profile Editing** | Working | Edit display name and photo |
| **Global Search** | Working | Search bar on Browse page filters approved items by query |
| **Image Gallery** | Working | Item detail shows all photos; full gallery screen with viewer |
| **Firestore Security Rules** | Deployed | Admin-only moderation, owner-limited updates (latest `claimed` change needs re-deploy) |
| **Firestore Indexes** | Deployed | Composite indexes for efficient queries |
| **Storage Rules** | Deployed | Authenticated users can upload with size/type limits |
| **Cloud Functions** | Deployed | OTP delivery, FCM push notifications, moderation migration (Node 22) |

### Partially Implemented / Placeholder

| Feature | Status | Notes |
|---------|--------|-------|
| **AI Camera Scanner** | Placeholder | UI exists but no actual AI/Gemini integration |
| **Admin Sidebar Sections** | Placeholder | Reports section shows placeholder |
| **Pull-to-refresh** | Partial | Exists on browse page, missing on grid pages |

### Known Blockers

| Issue | Priority | Status |
|-------|----------|--------|
| Latest Firestore rules change not deployed | P0 | Owner `claimed` status update — run `firebase deploy --only firestore:rules` |
| Admin doc `isAdmin: true` not verified | P0 | `lookupAdminUid()` needs `users/{uid}.isAdmin == true` on the admin user |
| Moderation migration not run | P1 | Tap "Run Moderation Migration" in admin Settings |
| Admin inbox lacks unread badges / last-message preview | P2 | Polish task |

---

## Features To Be Added

### Priority 1: Critical (Must Fix)

1. **Deploy Firestore Rules** — Run `firebase deploy --only firestore:rules` to enable the owner `claimed` status update
2. **Verify Admin Setup** — Confirm admin user doc has `isAdmin: true`; run the moderation migration from admin Settings
3. **Deploy Cloud Functions** — `firebase deploy --only functions` (Node 22) for push notifications

### Priority 2: Core Features

4. **AI Camera Scanner** — Integrate Gemini Vision API for real-time item recognition and matching
5. **Admin Inbox Polish** — Unread badges and last-message preview in `admin_inbox_screen.dart`

### Priority 3: Admin Features

6. **Admin Lost Items Section** — Show all lost items with filters (status, date, category)
7. **Admin Found Items Section** — Show all found items with filters
8. **Admin Reports Section** — Aggregated reports view with export capability
9. **Image Compression** — Compress before upload to save storage/bandwidth

### Priority 4: Polish & UX

10. **Pull-to-refresh** — Add to all grid/list pages
11. **Loading Skeletons** — Replace spinners with shimmer placeholders
12. **Empty States** — Better empty state illustrations and messaging
13. **Error Handling** — Graceful network error handling with retry options
14. **App Check** — Configure Firebase App Check to stop placeholder token warnings

### Priority 5: Tech Debt (DONE 2026-09-04)

- ~~Merge Chat Services~~ — `KashtepChatService` deleted; `ChatService` is the single chatbot backend
- ~~Remove Unused Models~~ — `AppMessage` model deleted
- ~~Node.js Upgrade~~ — Cloud Functions now target Node.js 22 (`functions/package.json`)

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
    notification_service.dart — FCM push notifications (tokens + foreground banner events)
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
  widgets/                   — 30+ reusable UI components (incl. notification_banner.dart, chatbot.dart)
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
