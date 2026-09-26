# dev_status.md — KAH KEN SHA NEY (amongapp) — Progress Log

Last updated: 2026-09-25
Project: `firstfirebase-5880d` · Flutter 3.44.8 / Dart 3.12.2 · Firebase CLI 15.24.0
Repo: `C:\APP FLUTTER\amongapp` (Windows, PowerShell — no `rg`, use grep tool)

---

## 1. Where we started

Two back-to-back work sessions:

### Session A — Full health sweep (analyze / tests / functions / rules / flows)
Starting state: 45 `flutter analyze` issues, Cloud Functions unverified,
production security rules **diverging from local files**, no E2E flow verification.

### Session B — Fix "Failed to submit report" → `[firebase_storage/unauthorized]`
`StorageException Code: -13040` when submitting Lost/Found reports with a photo.
Prompt constraints: lead with rules-vs-path comparison (character for character);
no blanket `allow write: if request.auth != null`; do NOT touch App Check unless
logs show `DebugAppCheckProvider` / failed-exchange lines (they didn't);
`Invalid ID 0x00000001` deprioritized; verify report/profile/chat uploads E2E.

**Root cause found (Session B):** production `storage.rules` was still the
auto-generated scaffold template with `allow read, write: if request.time <
timestamp.date(2026, 9, 17)` — expired → **every Storage write denied since
2026-09-17**. The local `storage.rules` (path-scoped rules) had never been
deployed. Upload paths themselves matched the local rules exactly — the local
file simply wasn't live.

---

## 2. Where we stopped (all work completed & verified)

### Session A — completed
- `flutter analyze`: 45 → **0 issues** (dart fix + manual: unused
  `browse_items_page.dart` accent surface, dead `_notificationsViewed` flag,
  renamed `count`/`sum` closures in dashboards, `ctx.mounted` guard in
  `admin_resolved_screen.dart`, `print` → `debugPrint`).
- `flutter build apk --debug` + `flutter build appbundle` ✓.
- `flutter test`: 130 tests (incl. new `test/regression_logic_test.dart` — 20
  tests for `peerChatId`, status transitions, admin-invite parsing, chatbot
  error mapping). `chat_service.dart` helpers exposed `@visibleForTesting`.
- Cloud Functions: `npm run build` / `lint` / `test` (31/31) clean; all 20
  callables deployed & region-matched; live probes returned 401 (auth-gated,
  not 404 → routing OK).
- `firestore.rules`: rewrote `chats/{chatId}` block — null-safe read with
  `resource == null && inPeerId()` existence probe; strict create (support
  thread under own UID only; peer thread `participants` must equal the 2 UIDs
  encoded in doc ID, using `[0]`/`[1]` indexing); null-safe update; `delete: false`.
  Added 10 admin-grant/admin-invites rules tests.
- Dependency flagging only (no upgrades): `cached_network_image` 3.4.1→4.0.2,
  `flutter_dotenv` 5.2.1→6.0.1, `google_fonts` 6.3.3→8.2.1 major-behind;
  KGP warning context: AGP 9.0.1 present but
  `android/gradle.properties` sets `android.builtInKotlin=false` (correct for
  Flutter 3.44.8; needs Flutter 3.47+ — future work, do NOT flip now).
- Dead asset noted: `.env` (`GEMINI_API_KEY`) bundled as asset but
  `dotenv['…']` never read — client-side leak candidate, not yet addressed.

### Session B — completed (Storage `unauthorized`)
1. **Task A diagnosis (evidence-backed):**
   - Deployed template fetched via Rules REST API (token from
     `%USERPROFILE%\.config\configstore\firebase-tools.json`) → expired
     `timestamp.date(2026, 9, 17)` → root cause. Saved snapshots:
     `%TEMP%\opencode\deployed_storage.rules`, `deployed_firestore.rules`
     (deployed firestore was also missing the `adminInvites` block).
   - Path diff — ALL client paths match local rules character-for-character:
     - reports: `lost_and_found/{lost|found}/{itemId}_{stamp}_{i}.jpg`
       (`report_lost_page.dart:95` / `submit_found_page.dart:96`)
     - profile post/avatar: `profiles/{uid}/posts|avatar_…`
       (`profile_provider.dart:105,140`)
     - chat: `chat_images/{fileName}` (`chat_image_uploader.dart:61`)
2. **Two latent local-rules bugs found by the emulator matrix, fixed:**
   - `storage.rules` deletes used `resource.metadataUploaderId` →
     runtime "Property metadataUploaderId is undefined" → all deletes
     denied. Fixed to `resource.metadata.metadataUploaderId` (3 rules).
   - Uploads **without an explicit `contentType`** are denied by
     `request.resource.contentType.matches('image/.*')` (platform can send
     `application/octet-stream`) — only `ChatImageUploader` set one.
     Fixed: `StorageService.contentTypeFor(path)` + explicit contentType in
     `StorageService._uploadMetadata` and both `profile_provider` putFile calls.
3. **Deployed + verified:**
   - `firebase deploy --only firestore:rules,storage` ✓
     (NOTE: correct syntax is `--only storage`, NOT `storage:rules` — CLI
     treats the suffix as a named target → "Could not find rules…" error).
   - Both deployed rulesets confirmed **byte-identical to local** via Rules
     REST API (normalize `\r` first; PS 5.1 `Get-Content` is ANSI → box-drawing
     comment chars mojibake in naive length diffs).
4. **Verification layers all green:**
   - Firestore rules tests: all pass (incl. 10 new admin-grant tests;
     required 2 fixes: `.get(n)` → `[n]` — `.get()` invalid on rules lists —
     and a paren-count fix after that conversion).
   - Storage rules matrix: **18/18** — new harness
     `rules-tests/storage_rules.test.mjs` (run:
     `firebase emulators:exec --only auth,storage --project firstfirebase-5880d
     "node rules-tests/storage_rules.test.mjs"`).
   - Production E2E: **5/5** — new `rules-tests/production_verify.mjs`
     (throwaway signup → report-photo upload at exact prod path →
     getDownloadURL → octet-stream control rejected → delete own upload →
     cleanup of user+objects).
   - `flutter analyze` 0 · `flutter test` **131/131** (added
     `contentTypeFor` regression test) · `flutter build apk --debug` ✓.
5. **Task B (App Check): untouched, correctly.** Error code was
   `storage/unauthorized` (≠ `storage/app-check-*`), no App Check log lines;
   App Check API not enabled for probing. `ChatImageUploader` already does
   best-effort token refresh.
6. **Task C (`Invalid ID 0x00000001`): no action needed.** Already mitigated
   by keep rule `android/app/proguard-rules.pro:15-19` (R$* fields after
   plugin bumps). Prompt says deprioritize.
7. **Task D (device E2E): NOT done as specified** — no physical device
   connected (`flutter devices` → Windows/Chrome/Edge only). Substituted
   with the production SDK E2E above. 3 AVDs exist:
   `Pixel_10_Pro_XL`, `Pixel_8`, `Resizable_Experimental`.

### Changed files this session (Session B)
```
M  firebase.json                     auth+storage emulator ports (127.0.0.1:9099/9199)
M  storage.rules                     3× resource.metadata.metadataUploaderId fix
M  lib/data/storage/storage_service.dart      contentTypeFor + explicit contentType
M  lib/providers/profile_provider.dart        explicit contentType ×2 + import
M  test/storage_paths_test.dart               contentTypeFor regression test
M  rules-tests/storage_rules.test.mjs         18-check rules matrix harness
?? rules-tests/production_verify.mjs          production E2E script (safe: self-cleaning)
```
(Not in git status → already committed earlier: `firestore.rules`,
`test/regression_logic_test.dart`, `lib/services/chat_service.dart`, etc.)

---

## 3. Where we should start later

Priority order:

1. **Physical-device E2E (Task D, unfinished):** connect a device or launch
   `Pixel_8`, then verify on-device: Lost report with photo, Found report,
   profile photo, chat image. Fastest path: run
   `flutter run` + log in (production rules are live and proven at the API
   layer, so the upload path should pass), or write an `integration_test`
   driving `report_lost_page` → submit.
2. **Rerun both rules suites before ANY future rules change:**
   - `firebase emulators:exec --only firestore --project firstfirebase-5880d "npm --prefix rules-tests test"`
   - `firebase emulators:exec --only auth,storage --project firstfirebase-5880d "node rules-tests/storage_rules.test.mjs"`
   - deploy: `firebase deploy --only firestore:rules,storage --project firstfirebase-5880d`
3. **Google deps major-behind (flagged, not upgraded by policy):**
   `cached_network_image` 4.x, `flutter_dotenv` 6.x, `google_fonts` 8.x —
   upgrade one at a time with full test run.
4. **KGP future breakage:** when moving to Flutter ≥3.47, revisit
   `android.builtInKotlin=false` (AGP 9.0.1 expects built-in Kotlin).
5. **`.env` `GEMINI_API_KEY` bundled as Flutter asset but never read** —
   remove from assets or move server-side (chatbot already uses the Functions
   secret `GEMINI_API_KEY`; confirm no other reader before deleting).
6. **Callable happy-paths still untested live** (only 401 probes done):
   authenticate via emulator (`firebase emulators:exec --only auth,functions,firestore`)
   or a signed-in account to exercise `kashtep` real response, `claimItem`,
   `resolveItem`, `confirmMatch`.
7. **Housekeeping:** decide whether `rules-tests/production_verify.mjs`
   stays (it creates/deletes a throwaway user — harmless but should be known);
   App Check enforcement review in console when App Check API is enabled.
