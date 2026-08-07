import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/models/lost_found_item.dart';
import 'package:amongapp/pages/choose_action_page.dart';
import 'package:amongapp/pages/report_lost_page.dart';
import 'package:amongapp/pages/submit_found_page.dart';
import 'package:amongapp/theme/app_theme.dart';

Widget _app({required Widget home}) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: home,
    routes: {
      '/choose-action': (_) => const ChooseActionPage(),
      '/report-lost': (_) => const ReportLostPage(),
      '/submit-found': (_) => const SubmitFoundPage(),
    },
  );
}

/// Enlarges the test viewport so long form pages lay out fully.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Choose Action screen shows the question and both options',
      (tester) async {
    await tester.pumpWidget(_app(home: const ChooseActionPage()));

    expect(find.text('What would you like to do?'), findsOneWidget);
    expect(find.text('Report Lost Item'), findsOneWidget);
    expect(find.text('Submit Found Item'), findsOneWidget);
  });

  testWidgets('Report Lost Item routes to the lost form', (tester) async {
    await tester.pumpWidget(_app(home: const ChooseActionPage()));

    await tester.tap(find.text('Report Lost Item'));
    await tester.pumpAndSettle();

    expect(find.text('Item Name'), findsOneWidget);
    expect(find.text('Location Lost'), findsOneWidget);
    expect(find.text('Date Lost'), findsOneWidget);
  });

  testWidgets('Submit Found Item routes to the found form', (tester) async {
    await tester.pumpWidget(_app(home: const ChooseActionPage()));

    await tester.tap(find.text('Submit Found Item'));
    await tester.pumpAndSettle();

    expect(find.text('Location Found'), findsOneWidget);
    expect(find.text('Storage Location'), findsOneWidget);
    expect(find.text('Date Found'), findsOneWidget);
  });

  testWidgets('Lost form shows validation errors for empty fields',
      (tester) async {
    _tallSurface(tester);
    await tester.pumpWidget(_app(home: const ReportLostPage()));

    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(find.text('Item name is required.'), findsOneWidget);
    expect(find.text('Category is required.'), findsOneWidget);
    expect(find.text('Location is required.'), findsOneWidget);
    expect(find.text('Date is required.'), findsOneWidget);
  });

  testWidgets('Found form shows validation errors for empty fields',
      (tester) async {
    _tallSurface(tester);
    await tester.pumpWidget(_app(home: const SubmitFoundPage()));

    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(find.text('Category is required.'), findsOneWidget);
    expect(find.text('Location is required.'), findsOneWidget);
    expect(find.text('Storage location is required.'), findsOneWidget);
    expect(find.text('Date is required.'), findsOneWidget);
  });

  testWidgets('Lost form submits a valid item to the injected handler',
      (tester) async {
    _tallSurface(tester);
    LostFoundItem? submitted;
    await tester.pumpWidget(
      _app(
        home: ReportLostPage(
          onSubmit: (item, photos) async {
            submitted = item;
            expect(photos, isEmpty);
          },
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Item Name'),
      'Black Tumbler',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Electronics').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Location Lost'),
      'Library Level 2',
    );
    await tester.tap(find.text('Date Lost'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.kind, ItemKind.lost);
    expect(submitted!.title, 'Black Tumbler');
  });

  testWidgets('Found form submits a valid item to the injected handler',
      (tester) async {
    _tallSurface(tester);
    LostFoundItem? submitted;
    await tester.pumpWidget(
      _app(
        home: SubmitFoundPage(
          onSubmit: (item, photos) async {
            submitted = item;
          },
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keys').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Location Found'),
      'Main Gate',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Storage Location'),
      'Lost & Found Office',
    );
    await tester.tap(find.text('Date Found'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.kind, ItemKind.found);
    expect(submitted!.location, 'Main Gate');
    expect(submitted!.storageLocation, 'Lost & Found Office');
  });
}
