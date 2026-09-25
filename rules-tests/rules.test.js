/**
 * Firestore security-rules tests.
 *
 * Run from the repo root:
 *   firebase emulators:exec --only firestore --project firstfirebase-5880d "npm --prefix rules-tests test"
 *
 * The suite documents the expected behaviour of the `chats` rules, in
 * particular the peer-chat flow (`chats/peer_{uidA}_{uidB}`) where the very
 * first read happens before the document exists.
 */
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  addDoc,
  collection,
} = require('firebase/firestore');

const ALICE = 'aliceUID000000000000000001';
const BOB = 'bobUID00000000000000000002';
const MALLORY = 'malloryUID000000000000003';
const ADMIN = 'adminUID00000000000000004';
const LEGACY_ADMIN = 'legacyadminUID00000000005';

let testEnv;

function db(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function seed(callback) {
  return testEnv.withSecurityRulesDisabled((ctx) => callback(ctx.firestore()));
}

function peerChatId(uid1, uid2) {
  const sorted = [uid1, uid2].sort();
  return `peer_${sorted[0]}_${sorted[1]}`;
}

function peerChatData(participants) {
  return {
    participants,
    lastMessage: '',
    lastMessageAt: null,
    unreadByAdmin: false,
    unreadByUser: false,
    unreadByAdminCount: 0,
    unreadByUserCount: 0,
    isPeerChat: true,
  };
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'firstfirebase-5880d',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

test('peer chat: initiator can read the thread before it exists', async () => {
  // Regression test: the old rules read `resource.data.participants`, which
  // is null for a not-yet-created document, so the very first `get()` of a
  // new peer thread returned PERMISSION_DENIED.
  await assertSucceeds(getDoc(doc(db(ALICE), `chats/${peerChatId(ALICE, BOB)}`)));
});

test('peer chat: the other participant can also read before it exists', async () => {
  await assertSucceeds(getDoc(doc(db(BOB), `chats/${peerChatId(ALICE, BOB)}`)));
});

test('peer chat: a stranger cannot read the thread', async () => {
  await assertFails(getDoc(doc(db(MALLORY), `chats/${peerChatId(ALICE, BOB)}`)));
});

test('peer chat: initiator creates the thread with both participants', async () => {
  const chatId = peerChatId(ALICE, BOB);
  await assertSucceeds(
    setDoc(doc(db(ALICE), `chats/${chatId}`), peerChatData([ALICE, BOB])),
  );
  const snap = await getDoc(doc(db(ALICE), `chats/${chatId}`));
  assert.equal(snap.exists(), true);
});

test('peer chat: second participant can read the existing thread', async () => {
  const chatId = peerChatId(ALICE, BOB);
  await seed((firestore) =>
    setDoc(doc(firestore, `chats/${chatId}`), peerChatData([ALICE, BOB])),
  );
  await assertSucceeds(getDoc(doc(db(BOB), `chats/${chatId}`)));
});

test('peer chat: both participants can send messages', async () => {
  const chatId = peerChatId(ALICE, BOB);
  await seed((firestore) =>
    setDoc(doc(firestore, `chats/${chatId}`), peerChatData([ALICE, BOB])),
  );
  await assertSucceeds(
    addDoc(collection(db(ALICE), `chats/${chatId}/messages`), {
      senderId: ALICE,
      text: 'hello',
      isAdmin: false,
      timestamp: null,
    }),
  );
  await assertSucceeds(
    addDoc(collection(db(BOB), `chats/${chatId}/messages`), {
      senderId: BOB,
      text: 'hi there',
      isAdmin: false,
      timestamp: null,
    }),
  );
});

test('peer chat: a participant cannot forge another senderId', async () => {
  const chatId = peerChatId(ALICE, BOB);
  await seed((firestore) =>
    setDoc(doc(firestore, `chats/${chatId}`), peerChatData([ALICE, BOB])),
  );
  await assertFails(
    addDoc(collection(db(ALICE), `chats/${chatId}/messages`), {
      senderId: BOB,
      text: 'impersonating bob',
      isAdmin: false,
      timestamp: null,
    }),
  );
});

test('peer chat: a stranger cannot read or write messages', async () => {
  const chatId = peerChatId(ALICE, BOB);
  await seed((firestore) =>
    setDoc(doc(firestore, `chats/${chatId}`), peerChatData([ALICE, BOB])),
  );
  await assertFails(getDoc(doc(db(MALLORY), `chats/${chatId}/messages/m1`)));
  await assertFails(
    addDoc(collection(db(MALLORY), `chats/${chatId}/messages`), {
      senderId: MALLORY,
      text: 'sneaky',
      isAdmin: false,
      timestamp: null,
    }),
  );
});

test('peer chat: participants can update unread counters', async () => {
  const chatId = peerChatId(ALICE, BOB);
  await seed((firestore) =>
    setDoc(doc(firestore, `chats/${chatId}`), peerChatData([ALICE, BOB])),
  );
  await assertSucceeds(
    updateDoc(doc(db(BOB), `chats/${chatId}`), {
      lastMessage: 'hi',
      unreadByAdminCount: 1,
    }),
  );
});

test('peer chat: a stranger cannot update the thread', async () => {
  const chatId = peerChatId(ALICE, BOB);
  await seed((firestore) =>
    setDoc(doc(firestore, `chats/${chatId}`), peerChatData([ALICE, BOB])),
  );
  await assertFails(
    updateDoc(doc(db(MALLORY), `chats/${chatId}`), { lastMessage: 'mine now' }),
  );
});

test('peer chat: create must include the requesting user', async () => {
  const chatId = peerChatId(ALICE, BOB);
  await assertFails(
    setDoc(doc(db(MALLORY), `chats/${chatId}`), peerChatData([ALICE, BOB])),
  );
});

test('peer chat: create payload must match the participants encoded in the ID', async () => {
  const chatId = peerChatId(ALICE, BOB);
  // Mallory claims a thread that belongs to Alice and Bob by rewriting the
  // participants array to include herself.
  await assertFails(
    setDoc(doc(db(MALLORY), `chats/${chatId}`), peerChatData([MALLORY, BOB])),
  );
  // A participant pair that does not match the document ID is also refused.
  await assertFails(
    setDoc(doc(db(ALICE), `chats/${chatId}`), peerChatData([ALICE, MALLORY])),
  );
});

test('peer chat: create must list exactly the two IDs from the document ID', async () => {
  const chatId = peerChatId(ALICE, BOB);
  await assertFails(
    setDoc(doc(db(ALICE), `chats/${chatId}`), peerChatData([ALICE])),
  );
});

test('support chat: the owner can read their thread before it exists', async () => {
  await assertSucceeds(getDoc(doc(db(ALICE), `chats/${ALICE}`)));
});

test('support chat: another user cannot read a thread that does not exist', async () => {
  await assertFails(getDoc(doc(db(MALLORY), `chats/${ALICE}`)));
});

test('support chat: the owner creates their thread', async () => {
  await assertSucceeds(
    setDoc(doc(db(ALICE), `chats/${ALICE}`), {
      participants: [ALICE, ADMIN],
      lastMessage: '',
      lastMessageAt: null,
      unreadByAdmin: false,
      unreadByUser: false,
      unreadByAdminCount: 0,
      unreadByUserCount: 0,
    }),
  );
});

test('support chat: the owner cannot create a thread under someone else\'s UID', async () => {
  await assertFails(
    setDoc(doc(db(MALLORY), `chats/${ALICE}`), {
      participants: [MALLORY, ADMIN],
      lastMessage: '',
      lastMessageAt: null,
      unreadByAdmin: false,
      unreadByUser: false,
      unreadByAdminCount: 0,
      unreadByUserCount: 0,
    }),
  );
});

test('support chat: admin can read and update any thread', async () => {
  await seed(async (firestore) => {
    await setDoc(doc(firestore, `users/${ADMIN}`), { isAdmin: true });
    await setDoc(doc(firestore, `chats/${ALICE}`), {
      participants: [ALICE, ADMIN],
      lastMessage: '',
      unreadByAdminCount: 0,
    });
  });
  await assertSucceeds(getDoc(doc(db(ADMIN), `chats/${ALICE}`)));
  await assertSucceeds(
    updateDoc(doc(db(ADMIN), `chats/${ALICE}`), { unreadByAdminCount: 0 }),
  );
});

test('support chat: a legacy admin recorded only in participants can still read', async () => {
  await seed((firestore) =>
    setDoc(doc(firestore, `chats/${ALICE}`), {
      participants: [ALICE, LEGACY_ADMIN],
      lastMessage: '',
      unreadByAdminCount: 0,
    }),
  );
  await assertSucceeds(getDoc(doc(db(LEGACY_ADMIN), `chats/${ALICE}`)));
});

test('support chat: a stranger cannot read or update an existing thread', async () => {
  await seed((firestore) =>
    setDoc(doc(firestore, `chats/${ALICE}`), {
      participants: [ALICE, ADMIN],
      lastMessage: '',
      unreadByAdminCount: 0,
    }),
  );
  await assertFails(getDoc(doc(db(MALLORY), `chats/${ALICE}`)));
  await assertFails(
    updateDoc(doc(db(MALLORY), `chats/${ALICE}`), { lastMessage: 'hijack' }),
  );
});

test('support chat: messages require membership and the sender must be the caller', async () => {
  await seed((firestore) =>
    setDoc(doc(firestore, `chats/${ALICE}`), {
      participants: [ALICE, ADMIN],
      lastMessage: '',
    }),
  );
  await assertSucceeds(
    addDoc(collection(db(ALICE), `chats/${ALICE}/messages`), {
      senderId: ALICE,
      text: 'help',
      isAdmin: false,
      timestamp: null,
    }),
  );
  await assertFails(
    addDoc(collection(db(ALICE), `chats/${ALICE}/messages`), {
      senderId: ADMIN,
      text: 'forged as admin',
      isAdmin: true,
      timestamp: null,
    }),
  );
  await assertFails(
    addDoc(collection(db(MALLORY), `chats/${ALICE}/messages`), {
      senderId: MALLORY,
      text: 'intruder',
      isAdmin: false,
      timestamp: null,
    }),
  );
});

test('chats: nobody can delete a thread', async () => {
  await seed((firestore) =>
    setDoc(doc(firestore, `chats/${peerChatId(ALICE, BOB)}`), peerChatData([ALICE, BOB])),
  );
  const { deleteDoc } = require('firebase/firestore');
  await assertFails(deleteDoc(doc(db(ALICE), `chats/${peerChatId(ALICE, BOB)}`)));
});

// ── admin-grant path (users/{uid}) ────────────────────────────────────────
// Regression: admin assignment happens server-side only. A normal user must
// never be able to write `isAdmin`/`role` themselves, either at creation or
// by updating their own document afterwards.

test('admin grant: a user can create their own profile without privileged fields', async () => {
  await assertSucceeds(
    setDoc(doc(db(ALICE), `users/${ALICE}`), { name: 'Alice', email: 'alice@example.com' }),
  );
});

test('admin grant: a user cannot create their own profile with isAdmin set', async () => {
  await assertFails(
    setDoc(doc(db(ALICE), `users/${ALICE}`), { name: 'Alice', isAdmin: true }),
  );
  await assertFails(
    setDoc(doc(db(ALICE), `users/${ALICE}`), { name: 'Alice', role: 'admin' }),
  );
});

test('admin grant: a user cannot create a profile under another uid', async () => {
  await assertFails(
    setDoc(doc(db(MALLORY), `users/${ALICE}`), { name: 'Spoofed Alice' }),
  );
});

test('admin grant: a user cannot self-promote by updating their own document', async () => {
  await seed((firestore) =>
    setDoc(doc(firestore, `users/${ALICE}`), { name: 'Alice', email: 'alice@example.com' }),
  );
  await assertFails(updateDoc(doc(db(ALICE), `users/${ALICE}`), { isAdmin: true }));
  await assertFails(updateDoc(doc(db(ALICE), `users/${ALICE}`), { role: 'admin' }));
});

test('admin grant: a user can still update their own profile fields', async () => {
  await seed((firestore) =>
    setDoc(doc(firestore, `users/${ALICE}`), { name: 'Alice', email: 'alice@example.com' }),
  );
  await assertSucceeds(updateDoc(doc(db(ALICE), `users/${ALICE}`), { name: 'Alice Updated' }));
});

test('admin grant: an admin can grant isAdmin to another user', async () => {
  await seed(async (firestore) => {
    await setDoc(doc(firestore, `users/${ADMIN}`), { isAdmin: true });
    await setDoc(doc(firestore, `users/${ALICE}`), { name: 'Alice' });
  });
  await assertSucceeds(updateDoc(doc(db(ADMIN), `users/${ALICE}`), { isAdmin: true }));
});

test('admin grant: a non-admin cannot grant isAdmin to anyone', async () => {
  await seed(async (firestore) => {
    await setDoc(doc(firestore, `users/${ADMIN}`), { isAdmin: true });
    await setDoc(doc(firestore, `users/${ALICE}`), { name: 'Alice' });
  });
  await assertFails(updateDoc(doc(db(MALLORY), `users/${ALICE}`), { isAdmin: true }));
});

test('admin grant: nobody can delete another user\'s profile', async () => {
  await seed((firestore) => setDoc(doc(firestore, `users/${ALICE}`), { name: 'Alice' }));
  await assertFails(deleteDoc(doc(db(MALLORY), `users/${ALICE}`)));
  await assertSucceeds(deleteDoc(doc(db(ALICE), `users/${ALICE}`)));
});

test('admin invites: no client can write the adminInvites collection', async () => {
  await assertFails(setDoc(doc(db(ADMIN), 'adminInvites/inv1'), { email: 'x@example.com' }));
  await assertFails(setDoc(doc(db(ALICE), 'adminInvites/inv1'), { email: 'x@example.com' }));
});
