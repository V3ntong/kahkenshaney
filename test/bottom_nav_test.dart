import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/pages/home_feed.dart';
import 'package:amongapp/theme/app_theme.dart';
import 'package:amongapp/widgets/bottom_nav.dart';

Widget _navApp(int index, {Map<int, int> badges = const {}}) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      backgroundColor: AppColors.background,
      body: const SizedBox(),
      bottomNavigationBar: HomeBottomNav(
        selectedIndex: index,
        onSelected: (_) {},
        badges: badges,
      ),
    ),
  );
}

void main() {
  testWidgets('Bottom nav shows the new five-tab structure', (tester) async {
    await tester.pumpWidget(_navApp(0));

    // Labels are hidden visually but exposed as tooltips/accessibility hints.
    expect(find.text('Home'), findsNothing);
    expect(find.text('Lost'), findsNothing);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Found'), findsNothing);
    expect(find.text('Messages'), findsNothing);

    expect(find.byTooltip('Home'), findsOneWidget);
    expect(find.byTooltip('Lost'), findsOneWidget);
    expect(find.byTooltip('Reports'), findsOneWidget);
    expect(find.byTooltip('Found'), findsOneWidget);
    expect(find.byTooltip('Messages'), findsOneWidget);

    expect(find.byTooltip('AI Scan'), findsNothing);
    expect(find.byTooltip('Profile'), findsNothing);
  });

  testWidgets('Floating pill bar is dark and rounded', (tester) async {
    await tester.pumpWidget(_navApp(0));

    final pill = tester.widget<Container>(
      find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final deco = w.decoration;
        return deco is BoxDecoration &&
            deco.color == HomeBottomNav.defaultBarColor &&
            deco.borderRadius == BorderRadius.circular(32);
      }),
    );
    expect(pill, isNotNull);
  });

  testWidgets('Active tab renders the raised accent badge with a white icon',
      (tester) async {
    await tester.pumpWidget(_navApp(0));
    await tester.pump(const Duration(milliseconds: 400));

    // Exactly one filled accent circle (the active tab's raised badge).
    final accentCircles = tester.widgetList<Container>(
      find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final deco = w.decoration;
        return deco is BoxDecoration &&
            deco.color == HomeBottomNav.defaultAccentColor &&
            deco.shape == BoxShape.circle;
      }),
    );
    expect(accentCircles, hasLength(1));

    // The icon inside the active badge is white.
    expect(
      find.descendant(
        of: find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final deco = w.decoration;
          return deco is BoxDecoration &&
              deco.color == HomeBottomNav.defaultAccentColor &&
              deco.shape == BoxShape.circle;
        }),
        matching: find.byIcon(Icons.home_rounded),
      ),
      findsOneWidget,
    );
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

    await tester.tap(find.byTooltip('Lost'));
    expect(tapped, 1);

    await tester.tap(find.byTooltip('Found'));
    expect(tapped, 3);

    await tester.tap(find.byTooltip('Messages'));
    expect(tapped, 4);

    await tester.tap(find.byTooltip('Home'));
    expect(tapped, 0);
  });

  testWidgets('Unread and notification badges show their counts',
      (tester) async {
    await tester.pumpWidget(
      _navApp(0, badges: {4: 3, 0: 12}),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('3'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
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

    await tester.pumpWidget(_navApp(0, badges: {4: 99}));
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