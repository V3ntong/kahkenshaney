# KAH KEN SHA NEY — App Flow

Lost & Found platform. Flutter client + Firebase (Auth, Firestore, Storage, Functions, FCM, App Check). This doc maps every user flow from boot to deep feature.

Legend: `A → B` means screen A navigates to screen B (push unless noted). `pushReplacement`, `pushAndRemoveUntil`, `pushNamed` are called out where they matter.

---

## 1. App Boot (`lib/main.dart`)

```
main()
  ├─ dotenv.load()
  ├─ Firebase.initializeApp()
  │    └─ FAIL → _FirebaseErrorScreen
  │            └─ "Retry" → pushReplacement AmongApp  (re-boot attempt)
  ├─ AppCheck.activate()  (Play Integrity on release, Debug provider in dev)
  └─ runApp(AmongApp(firebaseReady))
       ├─ ChangeNotifierProvider<ProfileProvider>
       └─ MaterialApp(home: MainPage)
            routes: /choose-action → ChooseActionPage
                    /report-lost   → ReportLostPage
                    /submit-found  → SubmitFoundPage
```

## 2. Onboarding / Authentication

### Sign up (`MainPage` → `SignupScreen`)
- **Get Started** → SignupScreen (FadeSlide)
- SignupScreen:
  - Submit valid form → OTP screen (`purpose: verifyEmail`)
  - **Log In** → LoginScreen (pushReplacement)
  - **Terms** → TermsConditionsScreen (modal)
- OTP verify → `register()` + `createUserProfile()` → **SignupProfilePhotoScreen** (pushAndRemoveUntil)
- Profile photo (optional) → **DashboardScreen** (pushAndRemoveUntil)

### Log in (`LoginScreen`)
- Loads saved accounts (SharedPreferences via `SavedAccountsStore`) — tap fills, swipe removes
- **Login** → save account → `refreshAdminStatus()` → route decision:
  - `isAdminAuthenticated` → **AdminDashboardScreen** (pushAndRemoveUntil)
  - else → **DashboardScreen** (pushAndRemoveUntil)
- **Forgot Password?** → ForgotPasswordScreen
- **Sign Up** → SignupScreen

### Password recovery & change
```
Forgot Password ──sendPasswordResetOtp──> OTP(resetPassword) ──> ResetPasswordScreen(mode: forgot)
    -> resetPassword() -> SuccessScreen("Password Reset") -> LoginScreen (pushReplacement)

(Profile/Settings) Change Password ──sendChangePasswordOtp──> OTP(changePassword) ──> ResetPasswordScreen(mode: change)
    -> changePassword() -> SuccessScreen("Password Updated") -> DashboardScreen (pushAndRemoveUntil)
```

### Session guard
- `DashboardScreen` `_guardRoute()`: unauthenticated → LoginScreen (pushReplacement).
- `AdminDashboardScreen` guard: not admin → DashboardScreen (if authed) | LoginScreen (if not).

## 3. User Shell (`DashboardScreen` = `NotificationBannerHost` + `HomePage`)

- Live unread **admin-chat** badge (`chats/{uid}.unreadByUserCount`)
- Live unread **in-app notification** count (firestore `users/{uid}/notifications`)
- `NotificationService.initialize(uid)` saves FCM token on boot
- Chatbot FAB shown on every tab except Messages; first-login welcome overlay (tap to dismiss)
- Sign out → confirm → signOut → **LoginScreen** (pushAndRemoveUntil)

### Home tabs (`HomePage` = PageController + 5 `HomeBottomNav` tabs)

| Tab | Screen | Entry points |
|----|--------|--------------|
| 0 | Home feed | Search → BrowseItemsPage(initialSearchQuery) · Filter → BrowseItemsPage · Report Lost/Found → /choose-action · AI Scan → "coming soon" snackbar · Notifications bell → NotificationsScreen · item tap → ItemDetailScreen · avatar menu → Profile / Change Password / My Reports / Settings / Log out |
| 1 | Lost grid | CTA → /report-lost · item → ItemDetailScreen · gallery → ImageGalleryPage |
| 2 | Reports (resolved feed) | item → ItemDetailScreen |
| 3 | Found grid | CTA → /submit-found · item → ItemDetailScreen |
| 4 | Messages | admin support chat — not signed in → notice · no admin → missing · admin self → notice · else **UserChatScreen(userId, adminUid)** |

## 4. Reporting an Item

```
ChooseActionPage ── /choose-action ──┬─ "Report Lost"   ──/report-lost──>  ReportLostPage
                                    └─ "Found Something"──/submit-found──> SubmitFoundPage
```
- Both forms: name / category / color / date / location / photos
- Photos → Firebase Storage (`folder: lost|found`), then `ItemRepository.addItem`
- `notifyAdminNewReport` push to admin
- **CenteredSuccessOverlay** (1.2 s) → pop back
- Also reachable from Lost/Found tab CTAs and item-list empty states

## 5. Item Detail Core (`ItemDetailScreen`)

Live Firestore item subscription. Buttons appear by status + ownership:

- **Suggested Matches** — tap → pushReplacement ItemDetailScreen(matched item)
- **Claim This Item** (non-owner) → `ClaimApi.claimItem` → overlay "Claim submitted for review" → notify owner + admin (self-claim is rejected client + server side)
- **Contact Reporter** (non-owner) → push **UserChatScreen** peer chat with the item reporter
- **Confirm Match** (owner/admin) → `MatchApi.confirmMatch` → snackbar
- **Mark as Resolved** → `ResolveApi.resolveItem` → snackbar
- **Related items** → pushReplacement ItemDetailScreen
- **Photo tap** → full-screen photo viewer

## 6. Chat Flows

- **Admin support** (`Messages` tab → `UserChatScreen`): `chatId == userId`, admin replies from `AdminInboxScreen` → `AdminChatDetailScreen`
- **Peer-to-peer** (`Contact Reporter`): ensures a `chats/peer_{uidA}_{uidB}` doc, live messages, unread counters
- **Chatbot** (FAB → bottom sheet `ChatScreen`): KashTeP assistant, Gemini direct API (`ChatService`), clear-history option

## 7. Profile & Content

### User
- `ProfileScreen`: **Upload** → UploadScreen (add post → Storage `profiles/<uid>/posts/`) · **Edit Profile** → EditProfileScreen (save → snackbar → pop) · post tap → PostDetailScreen
- **My Reports** → `UserReportsScreen(ownerUid)`

### Settings (`SettingsScreen`)
- **Account**: Change Password · **Delete Account** (password reauth + type DELETE) → wipe Firestore + Auth user → LoginScreen
- **Preferences**: pushNotifications / itemMatchAlerts / chatMessages → `users/{uid}/preferences`
- **Legal**: Privacy Policy · Terms (in-app)
- **Support**: Help & FAQ · Contact Support · Report a Problem → ContactSupportScreen(initialSubject) → `supportMessages`

## 8. Notifications / Push

```
Firestore notification doc (users/{uid}/notifications)
  → sendPushNotification (Cloud Function)
  → FCM
  → system notification (background)  OR  foreground banner
```
- **NotificationsScreen** list — tap → fetch `relatedItemId` → ItemDetailScreen
- **NotificationBannerHost** (dashboard wrapper) — foreground push → slide-in banner:
  - payload `relatedItemId` → ItemDetailScreen
  - else → NotificationsScreen
- Unread red-dot badges on Home feed + Admin sidebar

## 9. Admin Flows (`AdminDashboardScreen`)

Guard: not admin → user dashboard or login. Sidebar sections:

| # | Section | Flow |
|---|---------|------|
| 0 | Dashboard | stats overview |
| 1 | Review Queue | pending items → bottom-sheet detail → **Approve** / **Reject** (+reason) · status ladder (pendingVerification → verified → matched → claimed → resolved → closed, each notifies reporter; resolved sets `resolvedByAdminId`) |
| 2 | Resolved | non-terminal items → **Mark Resolved** dialog (pickup date/location) → `resolveItem` Function w/ direct Firestore fallback |
| 3 | Reports | placeholder |
| 4 | Users | user management |
| 5 | Messages | AdminInboxScreen → AdminChatDetailScreen (admin replies `isAdmin: true`) |
| 6 | Profile | admin profile |
| 7 | Settings | moderation migration, etc. |
| — | Logout | confirm → signOut → **MainPage** (pushAndRemoveUntil) |

## 10. Item Lifecycle & Backend

### Status lifecycle
```
open → pendingVerification → verified → matched → claimed → resolved → closed
```
- Moderation: `pending → approved | rejected (+rejectionReason)` (public visibility gate)
- Matching: `itemMatchingOnCreate` Cloud Function scores candidates server-side (persisted `matchScores[]` on the item)

### Cloud Functions (deployed, us-central1, Node 22)
`claimItem · resolveItem · confirmMatch · grantAdminIfAuthorized · itemMatchingOnCreate · itemLifecycle · sendPushNotification · migrateModerationStatus · sendSignupOtp · verifySignupOtp · sendPasswordResetOtp · verifyPasswordResetOtp · sendChangePasswordOtp · verifyChangePasswordOtp · changePassword · resetPassword`

### Data layer
- `ItemRepository` — items CRUD + streams (matches, resolved feed, browse/search)
- `SupportChatService` — admin (`chats/{uid}`) + peer chats + messages
- `NotificationService` (firestore) — notification docs + read streams
- `StorageService` — image uploads (`lost/`, `found/`, `profiles/`)
- `AuthService` / `FirebaseAuthService` — auth + admin lookup (`lookupAdminUid`, `isAdminEmail`) + OTP/password functions
- `AdminRepository` — moderation, status ladder, resolved
- `ProfileProvider` — user doc + posts + stats streams


ohahay