// Production verification for the report-photo upload fix.
// Run: node rules-tests/production_verify.mjs   (from repo root; needs rules-tests/node_modules)
// Signs up a throwaway user, uploads via the exact production paths, then
// deletes both the object and the user. Exits non-zero on any failure.
import { initializeApp } from 'firebase/app';
import { getAuth, createUserWithEmailAndPassword } from 'firebase/auth';
import {
  getStorage, ref, uploadBytes, getDownloadURL, deleteObject,
} from 'firebase/storage';

const app = initializeApp({
  projectId: 'firstfirebase-5880d',
  apiKey: 'AIzaSyDbveD4ZUKOHdpiBZMOQR69A-Fc5MJFQWg',
  storageBucket: 'firstfirebase-5880d.firebasestorage.app',
});
const auth = getAuth(app);
const storage = getStorage(app);

const stamp = Date.now();
const failures = [];
let passed = 0;
function check(label, ok, detail = '') {
  if (ok) passed += 1;
  else failures.push(`${label} ${detail}`);
  console.log(`${ok ? 'PASS' : 'FAIL'} | ${label}${detail ? ' — ' + detail : ''}`);
}

const email = `storage-verify-${stamp}@example.com`;
const cred = await createUserWithEmailAndPassword(auth, email, 'VerifyPass123!');
const uid = cred.user.uid;
const idToken = await cred.user.getIdToken();
console.log(`created throwaway user ${uid}`);

const jpgBytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46]);

// 1. THE failing operation: report photo upload, exact production path.
const reportPath = `lost_and_found/lost/prodverify_${stamp}_0.jpg`;
try {
  await uploadBytes(ref(storage, reportPath), new Blob([jpgBytes], { type: 'image/jpeg' }), {
    contentType: 'image/jpeg',
    customMetadata: { metadataUploaderId: uid },
  });
  check('report photo upload (lost_and_found/lost) — the failing operation', true);
} catch (e) {
  check('report photo upload (lost_and_found/lost) — the failing operation', false, e.code);
}

// 2. Found-path upload.
try {
  await uploadBytes(ref(storage, `lost_and_found/found/prodverify_${stamp}_0.jpg`), new Blob([jpgBytes], { type: 'image/jpeg' }), { contentType: 'image/jpeg' });
  check('found photo upload (lost_and_found/found)', true);
} catch (e) {
  check('found photo upload (lost_and_found/found)', false, e.code);
}

// 3. Download URL (what the app stores in Firestore).
try {
  const url = await getDownloadURL(ref(storage, reportPath));
  check('getDownloadURL after upload', url.includes('firebasestorage'), url.slice(0, 60));
} catch (e) {
  check('getDownloadURL after upload', false, e.code);
}

// 4. Control: non-image content type must still be rejected (new rules active).
try {
  await uploadBytes(ref(storage, `lost_and_found/lost/prodverify_${stamp}_bad.jpg`), new Blob([jpgBytes]), { contentType: 'application/octet-stream' });
  check('control: octet-stream upload rejected', false, 'upload unexpectedly succeeded');
} catch (e) {
  check('control: octet-stream upload rejected', e.code === 'storage/unauthorized', e.code);
}

// 5. Delete own upload (fixed resource.metadata.metadataUploaderId rule).
try {
  await deleteObject(ref(storage, reportPath));
  check('delete own upload (metadata uploader rule)', true);
} catch (e) {
  check('delete own upload (metadata uploader rule)', false, e.code);
}

// Cleanup: remove leftover test object + the throwaway user.
try { await deleteObject(ref(storage, `lost_and_found/found/prodverify_${stamp}_0.jpg`)); } catch {}
try {
  await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=AIzaSyDbveD4ZUKOHdpiBZMOQR69A-Fc5MJFQWg`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken }),
  });
} catch {}
console.log('cleanup done');

console.log(`\n${passed} passed, ${failures.length} failed`);
for (const f of failures) console.log('  FAIL:', f);
process.exit(failures.length ? 1 : 0);
