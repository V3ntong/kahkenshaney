# Phase 0 — Codebase Audit Report

**Date:** 2026-09-04
**Baseline:** `flutter analyze` → 0 errors / 36 info-level lints · `flutter test` → **79/79 pass** · `functions npm test` → **19/19 pass** · `functions npm run build` → clean

---

## Feature / Screen Inventory

| Feature | Status | What's Missing | Priority | Effort |
|---|---|---|---|---|
| OTP Authentication (signup/login/reset/change) | ✅ Working | — | — | — |
| Lost & Found reporting | ✅ Working | `eventDate` not persisted (P1-5); `reportedBy` now stored | P0 | S |
| Admin moderation (approve/reject + reason) | ✅ Working | — | — | — |
| Item status pipeline + `StatusTrackerWidget` | ✅ Working | `pendingClaim` added; wire to `resolveItem` callable (P1-6) | P0 | M |
| Self-claim prevention | ✅ Working (server + client) | Tests exist (`functions/test/claims.test.js`, `test/item_model_test.dart`) | — | — |
| Smart matching (trigram scorer + stored `matchScores`) | ✅ Working | — | — | — |
| Match suggestions + notifications to both parties | ✅ Working | **No UI/API to confirm two reports as a linked match** (`matchedItemId` never set by a user flow) — Phase 2c gap | P1 | M |
| Claim flow (`claimItem` callable → `pendingClaim`) | ✅ Working | Admin "Confirm Claim" button exists in review queue | — | — |
| Mark as Resolved | ⚠️ Partial | `item_detail_screen.dart:353` writes `status: 'claimed'` directly (wrong terminal status, skips history/notification, admin-only) — replace with `resolveItem` callable (P1-6) | P0 | M |
| Notifications (in-app + FCM push + foreground banner) | ✅ Working | — | — | — |
| Bottom navigation (floating pill) | ✅ Working | — | — | — |
| Profile editing + avatar upload | ⚠️ Partial | `profiles/{uid}/...` uploads not covered by `storage.rules` (P1-3) | P0 | S |
| Admin avatar upload | ⚠️ Partial | `profiles/{adminUid}/avatar_...` not covered by rules (P1-3) | P0 | S |
| Chat images | ⚠️ Partial | `chat_images/...` not covered by rules; no uploader metadata (P1-3) | P0 | S |
| Image Gallery page | 🐛 Broken path | `storage_service.dart:66` reads `ref(folderName)` but uploads live under `lost_and_found/{folder}` (P1-4) | P0 | S |
| User profile creation | 🐛 `adminEmails` query | `database_service.dart:88-101` queries unreadable `adminEmails` collection → aborts profile writes (P1-1); client-side `isAdmin` write path (P1-2) | P0 | S |
| Firestore rules privilege escalation | 🐛 Self-promotion | `firestore.rules` `users/{uid}` update allows self-edit of `isAdmin` (P1-2) | P0 | S |
| AI Camera Scanner | ⛔ Stub | `ai_scan_page.dart:28` shows "coming soon" snackbar | P2 | XL |
| Admin Reports section | ⛔ Stub | `admin_dashboard.dart:271` → `_SectionPlaceholder` "coming soon" | P2 | M |
| Filters on Browse page | ⛔ Stub | `home_feed.dart:218` `onFilter: () => _comingSoon('Filters')` | P2 | M |
| Admin Lost/Found item list sections | ⛔ Stub | `admin_dashboard.dart:2163` placeholder | P2 | M |
| Saved accounts / account switcher | ⛔ Missing | Entirely absent (Phase 3) | P1 | L |
| Page entrance animations | ⛔ Missing | Only auth/landing have text animations (Phase 5) | P2 | M |
| Gemini API key location | ⚠️ Client-side | `chat_service.dart` bundles `GEMINI_API_KEY` in the binary — move server-side | P2 | M |

## Stubs / TODOs Found

- `lib/widgets/coming_soon_page.dart` — generic stub screen (still used by AI scan entry).
- `lib/pages/ai_scan_page.dart:28` — "AI analysis coming soon."
- `lib/screens/admin_dashboard.dart:271,286,2163,3039-3075` — placeholder admin sections ("This admin section is coming soon.").
- `lib/pages/home_feed.dart:112,200,218,224,232` — `_comingSoon` snackbars (Profile fallback, Notifications fallback, Filters, AI Scan, More features).
- `lib/pages/home_page.dart:61,116-120` — `_comingSoon` snackbar helper.

## Phase 1 Findings (file:line)

1. **Profile creation aborts**: `lib/data/firestore/database_service.dart:88-101` (`createUserProfile`) and `:138-150` (`ensureAdminProfile`) query `adminEmails` collection (no rule allows reading it → PERMISSION_DENIED) and write `isAdmin` client-side.
2. **Privilege escalation**: `firestore.rules` — `match /users/{uid}` update allows `request.auth.uid == uid` with no privileged-field guard; create also allows arbitrary fields.
3. **Storage rules gap**: `storage.rules` only covers `lost_and_found/{type}/{fileName}`; real uploads also go to `profiles/{uid}/posts/...` (`providers/profile_provider.dart:105`), `profiles/{uid}/avatar_...` (`profile_provider.dart:137`, `screens/admin_dashboard.dart:2720`), `chat_images/...` (`screens/user_chat_screen.dart:136`, `screens/admin_chat_detail_screen.dart:138`). No uploader metadata is attached anywhere, so the `metadataUploaderId` delete rule can never match (`data/storage/storage_service.dart:40`).
4. **Gallery path bug**: `data/storage/storage_service.dart:66` `fetchImagesFromFolder` reads `ref(folderName)` but uploads land at `lost_and_found/{folder}/...` (`:39`).
5. **`eventDate` missing**: `models/lost_found_item.dart` has no event date; `report_lost_page.dart:76-86` and `submit_found_page.dart:81-92` collect `_date` but never persist it.
6. **Resolve lifecycle**: `screens/item_detail_screen.dart:353-380` writes `status: 'claimed'` directly (admin-only; wrong terminal status; no history/notification; blocked for owners by rules).

## Out of Scope (confirmed pending, not part of this session)

- AI Camera Scanner (Gemini Vision integration)
- Admin Reports section with export
- Moving the Gemini API key server-side
- Emulator-based Firestore/Storage rule tests (require `firebase emulators:exec` + credentials; provided as documented manual checks instead)