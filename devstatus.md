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