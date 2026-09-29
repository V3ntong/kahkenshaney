import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:amongapp/models/lost_found_item.dart';
import 'package:amongapp/models/post_model.dart';
import 'package:amongapp/models/user_profile.dart';
import 'package:amongapp/providers/profile_provider.dart';
import 'package:amongapp/screens/profile_screen.dart';

/// Interface-only stub so the test never touches Firebase (ProfileProvider's
/// field initializers construct Firestore/Auth/Storage instances).
class _StubProfileProvider extends ChangeNotifier implements ProfileProvider {
  _StubProfileProvider({
    required this.user,
    required this.ownItems,
    required this.posts,
  });

  @override
  final UserProfile? user;

  @override
  final List<LostFoundItem> ownItems;

  @override
  final List<PostModel> posts;

  @override
  bool get isLoading => false;

  @override
  int get reportsCount => ownItems.length;

  @override
  int get foundCount => ownItems.where((i) => i.kind == ItemKind.found).length;

  @override
  int get lostCount => ownItems.where((i) => i.kind == ItemKind.lost).length;

  @override
  void startListening() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LostFoundItem _item(String id, ItemKind kind, String title) => LostFoundItem(
  id: id,
  kind: kind,
  title: title,
  description: 'desc',
  ownerUid: 'u1',
  media: const [],
);

Future<void> _pumpProfile(
  WidgetTester tester,
  _StubProfileProvider provider,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<ProfileProvider>.value(
        value: provider,
        child: const ProfileScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Profile shows header and posts empty state', (tester) async {
    await _pumpProfile(
      tester,
      _StubProfileProvider(
        user: const UserProfile(uid: 'u1', displayName: 'Jane Doe'),
        ownItems: const [],
        posts: const [],
      ),
    );

    expect(find.text('Jane Doe'), findsWidgets);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('No posts yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile renders Found/Lost sections with items', (tester) async {
    await _pumpProfile(
      tester,
      _StubProfileProvider(
        user: const UserProfile(uid: 'u1', displayName: 'Jane Doe'),
        ownItems: [
          _item('f1', ItemKind.found, 'Found Wallet'),
          _item('l1', ItemKind.lost, 'Lost Keys'),
        ],
        posts: const [],
      ),
    );

    // Header metric labels plus the two section headers both read Found/Lost.
    expect(find.text('Found'), findsNWidgets(2));
    expect(find.text('Lost'), findsNWidgets(2));
    expect(find.text('Found Wallet'), findsOneWidget);
    expect(find.text('Lost Keys'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
