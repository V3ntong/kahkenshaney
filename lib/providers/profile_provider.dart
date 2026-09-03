import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../data/firestore/item_repository.dart';
import '../models/lost_found_item.dart';
import '../models/post_model.dart';
import '../models/user_profile.dart';

/// Manages profile state: user data, posts, avatar updates, profile edits,
/// and user report statistics (Reports/Found/Lost counts).
///
/// Wraps Firestore streams for real-time updates and Firebase Storage for
/// avatar/post image uploads.
class ProfileProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserProfile? _user;
  List<PostModel> _posts = [];
  bool _isLoading = false;

  int _reportsCount = 0;
  int _foundCount = 0;
  int _lostCount = 0;

  UserProfile? get user => _user;
  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;

  int get reportsCount => _reportsCount;
  int get foundCount => _foundCount;
  int get lostCount => _lostCount;

  StreamSubscription? _userSub;
  StreamSubscription? _postsSub;
  StreamSubscription? _itemsSub;

  /// Starts listening to the current user's profile, posts, and items in Firestore.
  void startListening() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Listen to user profile
    _userSub = _db.collection('users').doc(uid).snapshots().listen((snap) {
      if (snap.exists && snap.data() != null) {
        _user = UserProfile.fromMap(uid, snap.data()!);
        notifyListeners();
      }
    }, onError: (_) {});

    // Listen to user's posts (newest first)
    _postsSub = _db
        .collection('users')
        .doc(uid)
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      _posts = snap.docs
          .map((doc) => PostModel.fromMap(doc.id, doc.data()))
          .toList();
      notifyListeners();
    }, onError: (_) {});

    // Listen to user's items to compute report statistics (only approved items)
    _itemsSub = ItemRepository().streamUserItems(uid).listen((items) {
      final approved = items.where((i) => i.moderationStatus == ModerationStatus.approved).toList();
      _reportsCount = approved.length;
      _foundCount = approved.where((i) => i.kind == ItemKind.found).length;
      _lostCount = approved.where((i) => i.kind == ItemKind.lost).length;
      notifyListeners();
    }, onError: (_) {});
  }

  /// Stops Firestore listeners to prevent memory leaks.
  void stopListening() {
    _userSub?.cancel();
    _postsSub?.cancel();
    _itemsSub?.cancel();
  }

  /// Uploads a new post image and saves it to Firestore.
  ///
  /// [imageFile] is the picked image file, [caption] is the user's text.
  /// Throws on upload or Firestore write failure.
  Future<void> addPost({
    required File imageFile,
    required String caption,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    _isLoading = true;
    notifyListeners();

    try {
      // Upload image to Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'profiles/$uid/posts/$timestamp.jpg';
      final ref = _storage.ref(path);
      await ref.putFile(imageFile);
      final imageUrl = await ref.getDownloadURL();

      // Save post document to Firestore
      await _db.collection('users').doc(uid).collection('posts').add({
        'userId': uid,
        'imageUrl': imageUrl,
        'caption': caption,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the user's avatar in Firebase Storage and Firestore.
  ///
  /// [imageFile] is the picked image file. Old avatar in Storage is not
  /// deleted to avoid race conditions with cached URLs.
  Future<void> updateAvatar(File imageFile) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    _isLoading = true;
    notifyListeners();

    try {
      // Upload new avatar
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'profiles/$uid/avatar_$timestamp.jpg';
      final ref = _storage.ref(path);
      await ref.putFile(imageFile);
      final photoUrl = await ref.getDownloadURL();

      // Update Firestore user document
      await _db.collection('users').doc(uid).update({'photoUrl': photoUrl});

      // Update Firebase Auth profile
      await _auth.currentUser?.updatePhotoURL(photoUrl);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the user's display name and bio in Firestore.
  ///
  /// Both fields are optional — only non-null values are written.
  Future<void> updateProfile({String? displayName, String? bio}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (bio != null) updates['bio'] = bio;

    if (updates.isEmpty) return;

    await _db.collection('users').doc(uid).update(updates);

    // Also update Firebase Auth display name if changed
    if (displayName != null) {
      await _auth.currentUser?.updateDisplayName(displayName);
    }
  }
}
