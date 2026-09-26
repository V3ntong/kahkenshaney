// Storage security-rules verification run under:
//   firebase emulators:exec --only auth,storage --project firstfirebase-5880d "node rules-tests/storage_rules.test.mjs"
// Validates every client upload path against storage.rules before deploy.
import { initializeApp } from 'firebase/app';
import {
  getAuth, connectAuthEmulator, createUserWithEmailAndPassword,
} from 'firebase/auth';
import {
  getStorage, connectStorageEmulator, ref, uploadBytes, getDownloadURL, deleteObject,
} from 'firebase/storage';

const PROJECT = 'firstfirebase-5880d';
const failures = [];
let passed = 0;

const BUCKET = 'firstfirebase-5880d.firebasestorage.app';
const app = initializeApp({ projectId: PROJECT, apiKey: 'fake-key', storageBucket: BUCKET });
const auth = getAuth(app);
connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
const storage = getStorage(app);
connectStorageEmulator(storage, '127.0.0.1', 9199);

const anonApp = initializeApp({ projectId: PROJECT, apiKey: 'fake-key', storageBucket: BUCKET }, 'anon');
const anonStorage = getStorage(anonApp);

const uid = (await createUserWithEmailAndPassword(auth, 'rules-tester@example.com', 'Password1!')).user.uid;

function check(label, actual, expected) {
  const ok = actual === expected;
  if (ok) passed += 1;
  else failures.push(`${label}: expected ${expected}, got ${actual}`);
  console.log(`${ok ? 'PASS' : 'FAIL'} | ${label} -> ${actual}`);
}

async function upload(path, { type, explicitType, uploader } = {}) {
  const blob = type ? new Blob([new Uint8Array(16)], { type }) : new Blob([new Uint8Array(16)]);
  const metadata = {};
  if (explicitType) metadata.contentType = explicitType;
  if (uploader) metadata.customMetadata = { metadataUploaderId: uploader };
  try {
    await uploadBytes(ref(storage, path), blob, metadata);
    return 'ALLOW';
  } catch (e) {
    console.log(`  (denied: ${e.code ?? e.message})`);
    return 'DENY';
  }
}

async function read(store, path) {
  try {
    await getDownloadURL(ref(store, path));
    return 'ALLOW';
  } catch (e) {
    console.log(`  (denied: ${e.code ?? e.message})`);
    return 'DENY';
  }
}

async function del(path) {
  try {
    await deleteObject(ref(storage, path));
    return 'ALLOW';
  } catch (e) {
    console.log(`  (denied: ${e.code ?? e.message})`);
    return 'DENY';
  }
}

// ── Report Lost / Submit Found (StorageService.uploadItemPhotos) ──────────
check('lost report photo (explicit contentType)',
  await upload('lost_and_found/lost/abc_1_0.jpg', { explicitType: 'image/jpeg', uploader: uid }), 'ALLOW');
check('found report photo (explicit contentType)',
  await upload('lost_and_found/found/abc_1_0.jpg', { explicitType: 'image/jpeg', uploader: uid }), 'ALLOW');
// Rules reject an absent/foreign content type; the client always sends an
// explicit image/* contentType (StorageService._uploadMetadata et al).
check('report photo, NO contentType rejected by rules',
  await upload('lost_and_found/lost/noct_1_0.jpg', { uploader: uid }), 'DENY');
check('report photo, octet-stream content type rejected',
  await upload('lost_and_found/lost/octet_1_0.jpg', { explicitType: 'application/octet-stream', uploader: uid }), 'DENY');
check('wrong type segment rejected',
  await upload('lost_and_found/other/x.jpg', { explicitType: 'image/jpeg' }), 'DENY');
check('png report photo allowed',
  await upload('lost_and_found/lost/png_1_0.png', { explicitType: 'image/png' }), 'ALLOW');

// ── Profile posts + avatar (profile_provider) ─────────────────────────────
check('own profile post',
  await upload(`profiles/${uid}/posts/1.jpg`, { explicitType: 'image/jpeg', uploader: uid }), 'ALLOW');
check('own avatar',
  await upload(`profiles/${uid}/avatar_1.jpg`, { explicitType: 'image/jpeg', uploader: uid }), 'ALLOW');
check('profile photo with NO contentType rejected by rules',
  await upload(`profiles/${uid}/posts/noct.jpg`, { uploader: uid }), 'DENY');
check("someone else's profile folder rejected",
  await upload('profiles/other-uid/avatar_1.jpg', { explicitType: 'image/jpeg' }), 'DENY');

// ── Chat images (ChatImageUploader) ───────────────────────────────────────
check('chat image',
  await upload('chat_images/c1.jpg', { explicitType: 'image/jpeg', uploader: uid }), 'ALLOW');
check('chat image over 10MB rejected',
  await (async () => {
    const blob = new Blob([new Uint8Array(11 * 1024 * 1024)], { type: 'image/jpeg' });
    try { await uploadBytes(ref(storage, 'chat_images/big.jpg'), blob); return 'ALLOW'; }
    catch (e) { console.log(`  (denied: ${e.code ?? e.message})`); return 'DENY'; }
  })(), 'DENY');

// ── Legacy / unknown paths ────────────────────────────────────────────────
check('legacy path denied',
  await upload('legacy/x.jpg', { explicitType: 'image/jpeg' }), 'DENY');

// ── Reads ─────────────────────────────────────────────────────────────────
check('authenticated read', await read(storage, 'lost_and_found/lost/abc_1_0.jpg'), 'ALLOW');
check('unauthenticated read', await read(anonStorage, 'lost_and_found/lost/abc_1_0.jpg'), 'DENY');

// ── Deletes ───────────────────────────────────────────────────────────────
check('delete own upload via metadataUploaderId',
  await del('lost_and_found/lost/abc_1_0.jpg'), 'ALLOW');
check('upload without uploader metadata is allowed',
  await upload('chat_images/nometa.jpg', { explicitType: 'image/jpeg' }), 'ALLOW');
check('delete a file without uploader metadata',
  await del('chat_images/nometa.jpg'), 'DENY');

console.log(`\n${passed} passed, ${failures.length} failed`);
for (const f of failures) console.log('  FAIL:', f);
process.exit(failures.length ? 1 : 0);
