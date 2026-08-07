import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/pages/home_feed.dart';
import 'package:amongapp/theme/app_theme.dart';
import 'package:amongapp/widgets/bottom_nav.dart';

Widget _navApp(int index) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      backgroundColor: AppColors.background,
      body: const SizedBox(),
      bottomNavigationBar: HomeBottomNav(
        selectedIndex: index,
        onSelected: (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('Bottom nav shows the new five-tab structure', (tester) async {
    await tester.pumpWidget(_navApp(0));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Lost'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Found'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);

    expect(find.text('AI Scan'), findsNothing);
    expect(find.text('Profile'), findsNothing);
    expect(find.text('AI Camera Scanner'), findsNothing);
  });

  testWidgets('Tapping a nav item reports the correct index', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: const SizedBox(),
          bottomNavigationBar: HomeBottomNav(
            selectedIndex: 0,
            onSelected: (i) => tapped = i,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Lost'));
    expect(tapped, 1);

    await tester.tap(find.text('Found'));
    expect(tapped, 3);

    await tester.tap(find.text('Messages'));
    expect(tapped, 4);

    await tester.tap(find.text('Home'));
    expect(tapped, 0);
  });

  testWidgets('Bottom nav has no overflow on narrow screens for any tab',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (var i = 0; i < 5; i++) {
      await tester.pumpWidget(_navApp(i));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'overflow at tab $i');
    }

    // The longest label pill on the smallest width must not overflow.
    await tester.pumpWidget(_navApp(2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home feed has no overflow on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          backgroundColor: AppColors.background,
          body: HomeFeed(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}