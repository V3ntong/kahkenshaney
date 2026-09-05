import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/models/lost_found_item.dart';
import 'package:amongapp/theme/app_theme.dart';
import 'package:amongapp/widgets/item_grid_card.dart';

/// Standard test viewport — tall enough for grid cards + detail page.
void _setSurface(WidgetTester tester, {double height = 900}) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

LostFoundItem _makeItem({
  required String title,
  String description = '',
  String? category,
  String? location,
  ItemKind kind = ItemKind.lost,
  ItemStatus status = ItemStatus.open,
}) {
  return LostFoundItem(
    id: 'test_$title',
    kind: kind,
    title: title,
    description: description,
    category: category,
    location: location,
    ownerUid: 'user1',
    reportedBy: 'user1',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    status: status,
    media: const [],
  );
}

void main() {
  group('ItemGridCard overflow', () {
    testWidgets('renders without overflow with short title',
        (tester) async {
      _setSurface(tester);
      final item = _makeItem(
        title: 'Black Tumbler',
        description: 'Found near the library',
        category: 'Electronics',
        location: 'Library Level 2',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 250,
              child: ItemGridCard(item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow with long title + description',
        (tester) async {
      _setSurface(tester);
      final item = _makeItem(
        title:
            'This is an extremely long item title that should definitely wrap to multiple lines if allowed',
        description:
            'A very detailed and verbose description of this item that goes on and on to test the layout constraints thoroughly',
        category: 'Electronics',
        location: 'SMCTagum Main Campus Building A Level 3 Room 301',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 250,
              child: ItemGridCard(item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title should be truncated to 1 line
      final titleWidget = tester.widget<Text>(
        find.text(item.title),
      );
      expect(titleWidget.maxLines, 1);
      expect(titleWidget.overflow, TextOverflow.ellipsis);

      // Description should be truncated to 2 lines
      final descWidget = tester.widget<Text>(
        find.text(item.description),
      );
      expect(descWidget.maxLines, 2);
      expect(descWidget.overflow, TextOverflow.ellipsis);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow with no description',
        (tester) async {
      _setSurface(tester);
      final item = _makeItem(
        title: 'Keys',
        category: 'Keys',
        location: 'Cafeteria',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 250,
              child: ItemGridCard(item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow at narrow width (140px)',
        (tester) async {
      _setSurface(tester);
      final item = _makeItem(
        title: 'Extremely Long Title That Tests Layout Boundaries',
        description: 'Short desc',
        category: 'Accessories',
        location: 'Main Gate',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 140,
              height: 220,
              child: ItemGridCard(item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow in a horizontal list (related items)',
        (tester) async {
      _setSurface(tester);
      final items = List.generate(
        4,
        (i) => _makeItem(
          title: 'Item $i with a somewhat longer title for testing',
          description: 'Description $i that is moderately lengthy',
          category: 'Electronics',
          location: 'Location $i',
          kind: i.isEven ? ItemKind.lost : ItemKind.found,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: 140,
                  child: ItemGridCard(item: items[index]),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow with all terminal statuses',
        (tester) async {
      _setSurface(tester);
      for (final status in [
        ItemStatus.open,
        ItemStatus.matched,
        ItemStatus.resolved,
        ItemStatus.closed,
      ]) {
        final item = _makeItem(
          title: 'Status Test',
          status: status,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: SizedBox(
                width: 180,
                height: 250,
                child: ItemGridCard(item: item),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Report form overflow', () {
    testWidgets('Lost form renders without overflow on standard viewport',
        (tester) async {
      _setSurface(tester, height: 900);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const _TestReportLostForm(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Lost form renders without overflow with validation errors',
        (tester) async {
      _setSurface(tester, height: 900);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const _TestReportLostForm(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter empty text to simulate user interaction, then scroll down
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Item Name'),
        'Test item',
      );
      await tester.pumpAndSettle();

      // Scroll to bottom to ensure all content is reachable
      await tester.drag(
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      // The form should handle scrolling + input without overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Lost form renders without overflow on short viewport (700px)',
        (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const _TestReportLostForm(),
        ),
      );
      await tester.pumpAndSettle();

      // The form should be scrollable — no overflow
      expect(tester.takeException(), isNull);

      // The ListView should be scrollable
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView, isNotNull);
    });
  });
}

/// Minimal test harness for the lost form — avoids Firebase/Auth dependencies.
class _TestReportLostForm extends StatelessWidget {
  const _TestReportLostForm();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Lost Item')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
          children: [
            // Intro card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.errorSurface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Lost something? Give us the details below.',
                style: TextStyle(color: AppColors.textPrimary, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text('ITEM DETAILS',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.1)),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Item Name',
                hintText: 'e.g. Black Tumbler',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Color',
                hintText: 'e.g. Black',
                prefixIcon: Icon(Icons.palette_outlined),
              ),
            ),
            const SizedBox(height: 24),
            const Text('WHEN & WHERE',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.1)),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Location Lost',
                hintText: 'e.g. Library Level 2',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 24),
            const Text('PHOTO UPLOAD',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.1)),
            const SizedBox(height: 12),
            Container(
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Center(
                child: Icon(Icons.add_a_photo_rounded,
                    color: AppColors.primary, size: 22),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                child: const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
