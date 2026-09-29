import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/shared/widgets/happy_moment_sheet.dart';

import '../support/plugin_stubs.dart';

Future<void> pumpSheet(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(body: HappyMomentSheet()),
  ));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => stubSharedPreferences());

  group('Tone and content', () {
    testWidgets('leads with the warm acknowledgement', (tester) async {
      await pumpSheet(tester);
      expect(find.text("You're doing great! 💛"), findsOneWidget);
      expect(find.text("Enjoying the app? We'd love your feedback."),
          findsOneWidget);
    });

    testWidgets('offers a clear way to rate and a graceful way out',
        (tester) async {
      await pumpSheet(tester);
      expect(find.widgetWithText(ElevatedButton, 'Rate the App'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Not now'), findsOneWidget);
    });

    testWidgets('accepts custom copy for a different milestone',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: HappyMomentSheet(
            title: 'Ten meals saved! 💛',
            message: 'Enjoying the app? We\'d love your feedback.',
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Ten meals saved! 💛'), findsOneWidget);
    });
  });

  group('Not a rating interface', () {
    // App Review rejects custom rating UI that stands in for the real thing.
    testWidgets('shows no stars and no score to pick', (tester) async {
      await pumpSheet(tester);

      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.byIcon(Icons.star_border), findsNothing);
      expect(find.byIcon(Icons.star_half), findsNothing);
      expect(find.byIcon(Icons.star_outline), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.textContaining('★'), findsNothing);

      for (final n in ['1', '2', '3', '4', '5']) {
        expect(find.widgetWithText(ElevatedButton, n), findsNothing);
        expect(find.widgetWithText(TextButton, n), findsNothing);
      }
    });

    testWidgets('never claims the App Store sheet will appear', (tester) async {
      await pumpSheet(tester);
      // StoreKit may show nothing at all, so promising it would be a lie.
      expect(find.textContaining('will open'), findsNothing);
      expect(find.textContaining('App Store'), findsNothing);
    });

    testWidgets('offers nothing in exchange for a review', (tester) async {
      await pumpSheet(tester);
      for (final word in ['free', 'unlock', 'reward', 'premium', 'discount']) {
        expect(find.textContaining(word, findRichText: true), findsNothing,
            reason: 'incentivising reviews breaches App Review guidelines');
      }
    });
  });

  group('Dismissal', () {
    testWidgets('"Not now" closes the sheet', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              // Matches HappyMomentSheet.maybeShow, which opens the sheet
              // scroll-controlled so the whole card is reachable.
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const HappyMomentSheet(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text("You're doing great! 💛"), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text("You're doing great! 💛"), findsNothing);
    });
  });

  group('Rendering', () {
    testWidgets('fits a small phone without overflowing', (tester) async {
      tester.view.physicalSize = const Size(750, 1334); // iPhone SE class
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await pumpSheet(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(body: HappyMomentSheet()),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text("You're doing great! 💛"), findsOneWidget);
    });
  });
}
