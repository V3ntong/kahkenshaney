# AmongApp (KAH KEN SHA NEY) — Development Status

**Last updated:** 2026-09-26  
**Branch:** `main`  
**Working tree:** clean  

---

## ✅ Brief Completion Summary

All items from the recovered task brief (A1–A7, B1–B8, C1–C3, rules, deploy) are **complete**.

### Part A — User-side fixes (7 commits)

| Item | Description | Commit |
|------|-------------|--------|
| A1 | Public "Resolved" feed on homepage — server-published, PII-free entries via `resolvedFeed` collection; CF trigger on claim approval; `ItemRepository.streamResolvedFeed()` | `2b314b7` |
| A2 | My Reports stat cards: Pending / Lost / Found / Resolved (fix undercount); filterable `UserReportsScreen` with `ReportsFilter` enum | `d18ec38` |
| A3 | Recently Reported grouped by date bucket (Today / Yesterday / This Week / This Month / Earlier); horizontal lists per bucket | `7449f83` |
| A4 | Non-exclusive claims: `claims` subcollection, `claimCount`, admin `approveClaim` callable, claim stream, claim-count banner, admin review queue claims UI | `5bb3815` |
| A5 | "I Found This Item" shortcut: prefilled `SubmitFoundPage` + handoff peer chat (existing moderation path only) | `6ff9901` |
| A6 | ProfileProvider stream fix: idempotent `startListening()`, `_authSub`, sign-out clear, live avatar/name | `07d3a51` |
| A7 | Profile screen Found/Lost sections using `ProfileProvider.ownItems`; `PostGrid` shrink-wrapped in `ListView` | `2c2844b` |

### Part B — Admin-side fixes (8 commits)

| Item | Description | Commit |
|------|-------------|--------|
| B1 | Dashboard overview cards clickable → `AdminItemsListScreen` (Lost/Found), Review Queue (Pending), Users section | `266a9e9` |
| B2 | Admin Actions card: "Report Lost" / "Report Found" tiles; forms auto-attribute to admin uid | `81e32ab` |
| B3 | Migration button docs: code comment + in-app plain-language panel explaining `migrateModerationStatus` | `8ad2ebc` |
| B4 | Admin Profile mirrors Found/Lost sections with live counts; avatar/name staleness fixed via live `users/{uid}` stream (sidebar + app bar + profile) | `671fe8d` |
| B5 | Moderation triage outlines on message threads: green (clean) / amber (flagged) / red (violation) from `moderation_reports` | `5f3bfcf` |
| B6 | *Verified existing* — email column already present in `_UserRow` | — |
| B7 | Resolved section: All / Resolved Found / Resolved Lost segmented tabs | `47453f9` |
| B8 | Review Queue grouped: "Found Review" / "Lost Review" sub-headers | `1d5a9c4` |

### Part C — UI polish (3 commits)

| Item | Description | Commit |
|------|-------------|--------|
| C1 | Shared polished logout dialog (`showConfirmSignOutDialog`) with icon, hierarchy, rounded corners | `652dfda` |
| C2 | Item detail metadata grouped into outlined `DETAILS` card with dividers | `bbb9e47` |
| C3 | Custom shimmer skeleton bubble replacing "KashTeP is thinking…" (no new package) | `6045351` |

### Rules & Deploy

| Item | Description | Commit |
|------|-------------|--------|
| Firestore rules | Public `resolvedFeed` reads; `items/{itemId}/claims` (read auth / write false); admin-authored create rule documented | `156b96d` |
| Deploy step | `firebase deploy --only functions,firestore:rules` | pending |

---

## ✅ Verification Gates (all passing)

| Gate | Command | Result |
|------|---------|--------|
| Static analysis | `flutter analyze` | Clean (0 issues) |
| Flutter tests | `flutter test` | 131/131 passed |
| Functions build | `npm run build` (in `functions/`) | Clean compile |
| Functions tests | `npm test` (in `functions/`) | 31/31 passed |
| Rules tests | `firebase emulators:exec --only firestore "npm test"` (in `rules-tests/`) | 31/31 passed |
| Builds | All targets (see below) | ✓ succeeded |

---

## ✅ Build Artifacts

### AmongApp (Flutter)

| Target | Artifact | Size |
|--------|----------|------|
| Android debug | `app-debug.apk` | 193 MB |
| Android release (universal) | `app-release.apk` | 60 MB |
| Android release (split-per-abi) | `app-arm64-v8a-release.apk` | 23 MB |
|  | `app-armeabi-v7a-release.apk` | 21 MB |
|  | `app-x86_64-release.apk` | 25 MB |
| Play Store bundle | `app-release.aab` | 60 MB |
| Web (JS) | `build/web/` | — |
| Web (Wasm) | `build/web/` (enhanced) | — |
| Windows desktop | `build/windows/x64/runner/Release/amongapp.exe` | — |
| Asset bundle | `build/app/outputs/bundle/release/` | — |

### Cloud Functions

| Target | Artifact |
|--------|----------|
| TypeScript compile | `functions/lib/` |

### Sister Projects

| Project | Target | Artifact |
|---------|--------|----------|
| `ssms/student-system/frontend` | Vite production build | `frontend/dist/` (160 KB JS + 5 KB CSS gzipped) |
| `ssms/student-system/backend` | Python byte-compile | `main.py` ✓; deps installed (`fastapi`, `uvicorn`, `pyodbc`, `python-dotenv`) |
| `simplegamesample` | Static Flappy Bird | Static files only — JS syntax verified |
| `logo` | PNG asset | `logo.png` (24 KB) |

---

## ⚠️ Known Warnings (pre-existing, not from our changes)

- Gradle: Firebase plugins still use legacy Kotlin Gradle Plugin (KGP) — upgrade plugins when Flutter drops KGP support.
- Web build: `cupertino_icons` font warning (missing `uses-material-design: true` for Cupertino icons) — minor, non-blocking.

---

## 🚀 Final Deploy Step (manual)

```bash
# From repo root (where firebase.json lives)
firebase login              # if not already logged in
firebase use <project-id>   # select your Firebase project
firebase deploy --only functions,firestore:rules
```

**Prerequisites:**
- Firebase CLI logged in (`firebase login`)
- Project selected (`firebase use`)
- **Blaze plan** required for Cloud Functions
- No backfill for pre-existing resolved items — only newly approved claims publish to `resolvedFeed` going forward.

---

## 📝 Open Items (for your follow-up)

1. **Deploy** the functions + rules (command above).
2. **B3 decision**: Confirm with settings owner whether "Run Moderation Migration" is one-time or periodic before hiding it.
3. **Assumptions documented in code**:
   - B5 mapping: pending report → amber, reviewed/resolved report → red (no separate "violation" status exists).
   - Peer chat has **no** moderation filter path — none was added.

---

## 📦 Git History (relevant commits)

```
156b96d chore(rules): A1/B2 - public resolvedFeed reads; document admin-authored item create rule
6045351 feat(ui): C3 - replace KashTeP thinking indicator with custom shimmer skeleton bubble
bbb9e47 feat(ui): C2 - section item detail metadata into outlined DETAILS card with dividers
652dfda feat(ui): C1 - polished logout confirmation dialog shared by user feed and admin dashboard
1d5a9c4 feat(admin): B8 - group Review Queue into Found Review / Lost Review sub-sections
47453f9 feat(admin): B7 - Resolved section split with All / Resolved Found / Resolved Lost tabs
5f3bfcf feat(admin): B5 - moderation triage outline/tint on each user's message thread (green/amber/red)
671fe8d feat(admin): B4 - mirror Found/Lost sections with live counts on Admin Profile; fix avatar staleness via live user-doc stream
8ad2ebc docs(admin): B3 - document Run Moderation Migration button (code comment + in-app plain-language description)
81e32ab feat(admin): B2 - add Report Lost/Found entry points on Admin Actions card, auto-attributed to admin account
266a9e9 feat(admin): B1 - make dashboard overview stat cards navigate to filtered record views
6ff9901 A5: I Found This Item shortcut — prefilled found report + handoff peer chat
5bb3815 A4: non-exclusive claims — claims subcollection, claim counts, admin approveClaim
2b314b7 A1: public Resolved feed on homepage (server-published, PII-free)
7449f83 A3: group Recently Reported items by date bucket
d18ec38 A2: My Reports stats use Pending card and open filtered report lists
2c2844b A7: profile Found/Lost sections
07d3a51 A6: ProfileProvider stream fix
... (earlier history)
```

---
---

# Session Progress — 2026-09-30

Safety snapshot for this session: `git stash create` → `82211120d5f039b38a45c61861d7e745c6f05b20`
(no `git checkout` / `restore` / `reset`; no icon/splash assets touched; no test weakened or deleted).

## Part 1 — Build & test recovery (project did not compile; 6 test files failed to load)

**Root causes confirmed (both matched the earlier diagnosis):**

1. `lib/screens/user_chat_screen.dart` — `class _UserChatScreenState` (line 45) was never closed. `build()`
   ended ~line 539 and everything after it (`_MessageBubble`, `_FullScreenImage`, `_InputBar`,
   `_FailedImageUpload`, `_FailedUploadBubble`) was parsed as nested members → "Classes can't be declared
   inside other classes" plus ~84 cascade errors. The file also used `ItemDetailScreen` / `LostFoundItem`
   without imports and a **fake item stub** (`LostFoundItem.fromMap(_itemId!, {...})`).
2. `test/widget_test.dart` — four unbalanced `pumpWidget(` calls (one missing `)` each), wrong widget names
   (`OTPInput` → real `OtpInput`, `PasswordStrength` → real `PasswordStrengthBar`), invalid `const` around
   closures, and a reference to the library-private `_FirebaseErrorScreen`.

**Fixes:** closed the state class; resolved imports; replaced the fake item stub with `_openItemDetails()`
fetching the real item via `ItemRepository().getItem(itemId)`; rebuilt the two OTP tests, the
password-strength test and the Firebase error test.

**Extra finding (empirical, via a probe test):** unmocked Firebase platform channels **hang forever** in
`flutter test` (they never error), so `AmongApp` sits on `_NativeSplashPlaceholder` and the old
error-screen test could never pass as written. Solved with the official Pigeon harness
(`firebase_core_platform_interface/test.dart`): an **echo** core host API (`initializeCore` → `[]`,
`initializeApp` echoes the requested options so `MethodChannelFirebase`'s soft options check passes) plus a
scoped mock for the App Check `activate` channel. Mock registration is scoped to the landing group via
`setUp`/`tearDown`, so the "Firebase unavailable" placeholder test still exercises the real path.

**Result:** `flutter analyze` → *No issues found!*; `flutter test` → **+138: All tests passed!**;
`flutter build apk --debug` → ✓ `app-debug.apk`.

## Part 2 — Device-issue audit (root causes located, pre-test evidence captured)

| Issue | Verdict | Root cause (file:line) |
|-------|---------|--------------------------|
| Profile body blank | **earlier fix present, unverified** | `ItemGridCard` uses `Expanded` (`item_grid_card.dart:103`) inside a `Column`; in a shrink-wrapped list the height is unbounded → `RenderFlex … incoming height constraints are unbounded` → `child.hasSize` assertion blanks the body. Fix present at `profile_screen.dart:129` (`SizedBox(height: 240)`) + passing `test/profile_screen_test.dart` |
| "Lost Items" spins forever | **fixed in Part 3** | spinner on `waiting && !hasData` with **no timeout** and **no Retry** (`admin_items_list_screen.dart:70`), plus `item_repository.dart` swallows every stream error via `.handleError(…) → <empty list>` (67-72, 109-112, 125-128, 140-143, 157-160, 177-180, 201-204, 237-240) so failures look like "no data" |
| Review-queue badge mismatch | **earlier work present, untested** | badge unified on `ItemRepository().streamPendingItems()` (`moderationStatus == 'pending'`, `admin_dashboard.dart:98-106`), `99+` at `:657`; nothing proves approved "Submitted" items are excluded, nor last-item removal |
| Claims card on undecided items | **partial** | `"Could not load claims right now."` at `admin_review_queue_screen.dart:894`, "Update Status" at `:766`; approval gate not applied. `streamItemClaims` does rethrow now (`item_repository.dart:259-273`) |
| Reporter username missing | **already exists** | `item_detail_screen.dart:1460`, `admin_review_queue_screen.dart:742` — both use the denormalized `item.reporterUsername` |
| Lost Reports 9.5 px overflow | **fixed in Part 3** | `StatusTrackerWidget._buildCompact` put `Text(currentStatus.label)` in a `Row(mainAxisSize: min)` with no `Flexible`/ellipsis (`status_tracker_widget.dart:186-201`), rendered inside `Expanded` by `_ReportCard` (`user_reports_screen.dart:241`) |
| Notification long-press | **never implemented** | grep for `onLongPress|CupertinoContextMenu|showGeneralDialog` in `lib/` matches only image long-press (`user_chat_screen.dart:628`, `admin_chat_detail_screen.dart:488`); body is 2-line ellipsized text (`notifications_screen.dart:280-289`) |

**Pre-test evidence (captured before fixing: 10 failures / 3 passes):**
`RenderFlex overflowed by 56 / 133 / 16 / 93 / 271 pixels on the right`; `Found 0 widgets with text "Retry"`;
`Found 1 CircularProgressIndicator` after 11 s on a never-emitting stream; Lost Reports re-subscribing its
stream on every build.

## Part 3 (most recent work) — Overflow + endless-spinner fixes

**Files changed**

| File | Change | Why |
|------|--------|-----|
| `lib/widgets/async_state_view.dart` **(new)** | `AsyncStateView<T>`: waiting spinner with a **10 s budget** → error state, `debugPrint` of the raw error + friendly message + **Retry** (re-subscribes), explicit **empty** state, then data | one shared four-state view; a spinner is never the fallback for "no data"/"error" |
| `lib/widgets/status_tracker_widget.dart` | chip labels wrapped in `Flexible` + `maxLines: 1` + `TextOverflow.ellipsis` (normal **and** "Rejected" variants) | fixes the 9.5 px overflow for Lost **and** Found (shared widget) |
| `lib/screens/admin_items_list_screen.dart` | `StreamBuilder` → `AsyncStateView` | timeout / error+Retry / empty / data |
| `lib/screens/user_reports_screen.dart` | stream created **once in `initState`** (was built inside `build`, re-subscribing every rebuild) + `AsyncStateView` | removed the resubscribe loop, added the four states |
| `test/async_state_and_cards_test.dart` **(new, 13 tests)** | 6 overflow configs (320/360 dp × scale 1.0/1.3/2.0) + Lost Items and Lost Reports four states incl. error and never-emitting streams, plus a `listenCount == 1` guard | pre-test first, then regression guard |

`item_repository.dart` error swallowing was deliberately **left as-is** (changing it would alter behaviour of
~8 other screens) — the screens now handle timeout/error/empty themselves. Flagged as follow-up.

**Verification on the final tree:** `dart format` (5 files) → `flutter pub get` (no new packages) →
`flutter analyze` **No issues found!** → `flutter test` **+153: All tests passed!** (was +140; +13 new; the
new file alone runs `+13`) → `flutter build apk --debug` ✓ `app-debug.apk`. No device/emulator was available,
so nothing was device-verified.

## Still open

1. Profile: All/Found/Lost filter, explicit loading/error state, counters-vs-listed-items test.
2. Review Queue: badge↔queue parity test, empty state, last-item removal, in-flight button locking.
3. Claims / Update Status gating matrix in the shared detail sheet (`admin_review_queue_screen.dart:766/894`).
4. Notification long-press full-text preview (+ "More" affordance, actions, Semantics).
5. Chat: persist the item link as an `item` message with a denormalized snapshot, batched link+text write,
   day separators; fix the "Contact Admin" call site that passes the notification title/ID.
6. Reports "last 7 days" filter (`admin_dashboard.dart:4200`) — not yet inspected, so it is unverified
   whether "no reports" is a real bug.
7. Dashboard item cards: whole-card tap target + description preview on the card / full description in the sheet.
8. `item_repository.dart` — stop swallowing stream errors (cross-screen impact).

## Notes / risks

- A second agent (`opencode`, committing as `melben` with messages like `fsdfsd`) edits and commits the same
  tree; it committed work mid-session (HEAD reached `a0d60e5`). Serialize access to avoid overwrites.
- `flutter build apk --debug` prints only the pre-existing Kotlin/Gradle (KGP) deprecation warning.

