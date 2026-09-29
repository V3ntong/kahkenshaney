// Pre-test battery: proves the async-state and card-overflow bugs before the
// fix and guards them afterwards.
import 'dart:async';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/data/firestore/item_repository.dart';
import 'package:amongapp/models/lost_found_item.dart';
import 'package:amongapp/screens/admin_items_list_screen.dart';
import 'package:amongapp/screens/user_reports_screen.dart';
import 'package:amongapp/widgets/status_tracker_widget.dart';

class _EchoCoreHostApi implements TestFirebaseCoreHostApi {
  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async =>
      CoreInitializeResponse(
        name: appName,
        options: initializeAppRequest,
        pluginConstants: <String?, Object?>{},
      );

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async =>
      <CoreInitializeResponse>[];

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async =>
      CoreFirebaseOptions(
        apiKey: 'k',
        appId: 'a',
        messagingSenderId: 'm',
        projectId: 'p',
      );
}

class _StubRepo extends ItemRepository {
  _StubRepo(this._stream);

  final Stream<List<LostFoundItem>> _stream;
  int listenCount = 0;

  @override
  Stream<List<LostFoundItem>> streamUserItems(String ownerUid) {
    listenCount++;
    return _stream;
  }
}

LostFoundItem _item({
  String id = 'i1',
  ItemKind kind = ItemKind.lost,
  String title = 'Black Umbrella',
  ItemStatus status = ItemStatus.open,
  ModerationStatus moderation = ModerationStatus.approved,
}) =>
    LostFoundItem(
      id: id,
      kind: kind,
      title: title,
      description: 'desc',
      ownerUid: 'u1',
      status: status,
      moderationStatus: moderation,
      createdAt: DateTime(2026, 9, 29),
    );

/// Pumps [child] at a fixed logical width / text scale.
Future<void> _pumpAt(
  WidgetTester tester,
  Widget child, {
  double width = 360,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width * 3, 640 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => TestFirebaseCoreHostApi.setUp(_EchoCoreHostApi()));

  group('Compact status chip does not overflow (Issue 6)', () {
    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('width $width, text scale $scale', (tester) async {
          await _pumpAt(
            tester,
            Row(
              children: [
                const SizedBox(width: 56, height: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('jfjfj', maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      const StatusTrackerWidget(
                        currentStatus: ItemStatus.pendingClaim,
                        compact: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Approved'),
              ],
            ),
            width: width,
            textScale: scale,
          );

          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Lost Items screen four states (Issues 2/3)', () {
    testWidgets('data', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AdminItemsListScreen(
          kind: ItemKind.lost,
          itemsStream: Stream.value([_item()]),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Black Umbrella'), findsOneWidget);
    });

    testWidgets('empty', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AdminItemsListScreen(
          kind: ItemKind.lost,
          itemsStream: Stream.value(const <LostFoundItem>[]),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('No Lost Items yet'), findsOneWidget);
    });

    testWidgets('error shows retry, not a spinner', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AdminItemsListScreen(
          kind: ItemKind.lost,
          itemsStream: Stream<List<LostFoundItem>>.error('boom'),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a stream that never emits times out into an error state',
        (tester) async {
      final controller = StreamController<List<LostFoundItem>>();
      addTearDown(controller.close);

      await tester.pumpWidget(MaterialApp(
        home: AdminItemsListScreen(
          kind: ItemKind.lost,
          itemsStream: controller.stream,
        ),
      ));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait past the 10s budget.
      await tester.pump(const Duration(seconds: 11));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('Lost Reports screen (Issues 2/6)', () {
    testWidgets('renders items and subscribes exactly once', (tester) async {
      final repo = _StubRepo(Stream.value([_item(title: 'jfjfj')]));

      await tester.pumpWidget(MaterialApp(
        home: UserReportsScreen(
          ownerUid: 'u1',
          filter: ReportsFilter.lost,
          repository: repo,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('jfjfj'), findsOneWidget);
      // Guards against re-creating the stream on every build.
      expect(repo.listenCount, 1);
    });

    testWidgets('error shows retry, not a spinner', (tester) async {
      final repo = _StubRepo(Stream<List<LostFoundItem>>.error('boom'));

      await tester.pumpWidget(MaterialApp(
        home: UserReportsScreen(
          ownerUid: 'u1',
          filter: ReportsFilter.lost,
          repository: repo,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a stream that never emits times out into an error state',
        (tester) async {
      final controller = StreamController<List<LostFoundItem>>();
      addTearDown(controller.close);
      final repo = _StubRepo(controller.stream);

      await tester.pumpWidget(MaterialApp(
        home: UserReportsScreen(
          ownerUid: 'u1',
          filter: ReportsFilter.lost,
          repository: repo,
        ),
      ));
      await tester.pump();

      await tester.pump(const Duration(seconds: 11));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

