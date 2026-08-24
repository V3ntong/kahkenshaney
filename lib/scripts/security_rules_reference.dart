// ──────────────────────────────────────────────────────────────────────────────
// Suggested Firebase Security Rules for Lost & Found
// ──────────────────────────────────────────────────────────────────────────────
//
// These rules are NOT auto-applied. Review and deploy manually via the
// Firebase Console → Firestore / Storage → Rules.
//
// Firestore rules (firestore.rules):
// ──────────────────────────────────────────────────────────────────────────────
//
// rules_version = '2';
// service cloud.firestore {
//   match /databases/{database}/documents {
//
//     // ── items ────────────────────────────────────────────────────────────
//     match /items/{itemId} {
//       // Anyone authenticated can read items (for browse/search).
//       allow read: if request.auth != null;
//
//       // Only the owner can create an item; ownerUid must match auth uid.
//       allow create: if request.auth != null
//         && request.resource.data.ownerUid == request.auth.uid
//         && request.resource.data.keys.hasAll([
//              'kind', 'title', 'description', 'ownerUid', 'status', 'media'
//            ]);
//
//       // Only the owner or an admin can update.
//       allow update: if request.auth != null
//         && (resource.data.ownerUid == request.auth.uid
//             || request.auth.token.admin == true);
//
//       // Only the owner or an admin can delete.
//       allow delete: if request.auth != null
//         && (resource.data.ownerUid == request.auth.uid
//             || request.auth.token.admin == true);
//     }
//
//     // ── users ────────────────────────────────────────────────────────────
//     match /users/{uid} {
//       allow read: if request.auth != null;
//       allow write: if request.auth != null && request.auth.uid == uid;
//     }
//   }
// }
//
// Storage rules (storage.rules):
// ──────────────────────────────────────────────────────────────────────────────
//
// rules_version = '2';
// service firebase.storage {
//   match /b/{bucket}/o {
//
//     // ── lost_and_found images ────────────────────────────────────────────
//     match /lost_and_found/{type}/{fileName} {
//       // Anyone authenticated can read images.
//       allow read: if request.auth != null;
//
//       // Only authenticated users can upload; path must match type.
//       allow create: if request.auth != null
//         && (type == 'lost' || type == 'found')
//         && request.resource.contentType.matches('image/.*');
//
//       // Only the uploader (matched via metadata) or admin can delete.
//       allow delete: if request.auth != null
//         && request.auth.uid == resource.metadataUploaderId;
//     }
//
//     // ── everything else (legacy paths) ───────────────────────────────────
//     match /{allPaths=**} {
//       allow read: if request.auth != null;
//       allow write: if false; // Block new writes to legacy paths.
//     }
//   }
// }
//
// Indexes needed (firestore.indexes.json):
// ──────────────────────────────────────────────────────────────────────────────
//
// {
//   "indexes": [
//     {
//       "collectionGroup": "items",
//       "queryScope": "COLLECTION",
//       "fields": [
//         { "fieldPath": "kind", "order": "ASCENDING" },
//         { "fieldPath": "createdAt", "order": "DESCENDING" }
//       ]
//     }
//   ]
// }
//
// ──────────────────────────────────────────────────────────────────────────────
