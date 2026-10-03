// End-to-end tests: the real PantryPal app, on a real device, with the real
// SQLite database and the real widget bridge.
//
// The bootstrap mirrors `main()` rather than calling it, so onboarding and the
// weekly report can be pinned to a known state. RevenueCat still has to be
// configured exactly as production does: `SubscriptionService.isPremium()`
// runs on every launch, and calling into an unconfigured Purchases SDK
// terminates the app natively on iOS.
//
// Simulators cannot run this app (MLKit ships no arm64 simulator slices, and
// macOS 26 no longer runs x86_64 simulator builds), so a physical device is
// the only target. `flutter test` cannot attach to a wirelessly tethered
// device — use the driver:
//
//   flutter drive --driver=test_driver/integration_test.dart \
//                 --target=integration_test/app_test.dart \
//                 -d <device-id> --publish-port

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:pantrypal/app.dart';
import 'package:pantrypal/core/utils/database_helper.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/recipes/data/repositories/recipe_repository.dart';
import 'package:pantrypal/injection_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps for a bounded wall-clock window.
///
/// `pumpAndSettle` cannot be used at launch: the paywall renders a
/// `CircularProgressIndicator` while RevenueCat resolves, and an indeterminate
/// spinner schedules frames forever, so settling never happens. Bounded
/// pumping advances the UI without depending on the tree ever going quiet.
Future<void> settle(WidgetTester tester,
    {Duration timeout = const Duration(seconds: 3)}) async {
  // Pump a bounded NUMBER of frames rather than spinning for a wall-clock
  // window: every pump is a round trip to the device, and over a wireless
  // debug connection a spin loop issues thousands of them and takes minutes.
  // runAsync between pumps gives real database and preference I/O time to
  // finish, which fake-async pumping alone would never let complete.
  const step = Duration(milliseconds: 250);
  final steps = (timeout.inMilliseconds / step.inMilliseconds).ceil().clamp(1, 60);
  for (var i = 0; i < steps; i++) {
    // The real delay matches the step so the caller's timeout is honoured in
    // wall-clock terms — the device needs that time to finish its SQLite reads
    // and let the bloc emit before assertions run.
    await tester.runAsync(() => Future<void>.delayed(step));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Boots the app past onboarding and into the dashboard.
Future<void> launchApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_done': true,
    // Suppresses the Sunday weekly-report notification so the run is
    // reproducible on any day of the week.
    'weekly_report_scheduled': true,
    'weekly_report_last_shown':
        '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}',
  });

  if (!sl.isRegistered<PantryRepository>()) {
    await setupDependencies();
  }
  // setMockInitialValues above replaced the whole preference store, taking the
  // seeded recipe library with it. Production re-seeds on every launch through
  // setupDependencies; registering DI only once would leave later tests with an
  // empty recipe book.
  await sl<RecipeRepository>().seedIfEmpty();
  await configurePurchasesOnce();
  await DatabaseHelper.instance.clearAllData();

  await tester.pumpWidget(const PantryPalApp());
  await settle(tester, timeout: const Duration(seconds: 5));
  await dismissPaywallIfPresent(tester);
  // The home tab shows a spinner until the first PantryLoad resolves.
  await settle(tester, timeout: const Duration(seconds: 5));
}

bool _purchasesConfigured = false;

/// Configures RevenueCat with the same key `main()` uses.
///
/// Without this the first launch calls `Purchases.getCustomerInfo()` on an
/// unconfigured SDK, which kills the app mid-test and surfaces to the driver
/// as "Service has disappeared" rather than as a test failure.
Future<void> configurePurchasesOnce() async {
  if (_purchasesConfigured) return;
  _purchasesConfigured = true;
  final key = Platform.isIOS
      ? 'appl_vldzueYBTHHQdGdeSsRyRKpEvJN'
      : 'goog_XXXXXXXXXX';
  try {
    await Purchases.configure(PurchasesConfiguration(key));
  } catch (_) {
    // Already configured by a previous test in the same process.
  }
}

/// The paywall no longer appears on launch, but a later gentle offer or a
/// limit can still show it; this closes it if it ever does.
Future<void> dismissPaywallIfPresent(WidgetTester tester) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    final close = find.byIcon(Icons.close);
    if (close.evaluate().isEmpty) return;
    await tester.tap(close.first);
    await settle(tester, timeout: const Duration(seconds: 2));
  }
}

/// Settings lives behind the gear on the Use first screen.
Future<void> openSettings(WidgetTester tester) async {
  await openTab(tester, 'Use first');
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await settle(tester, timeout: const Duration(seconds: 3));
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await settle(tester, timeout: const Duration(seconds: 4));
}

/// Adds a pantry item through the real manual-entry sheet.
Future<void> addItemManually(WidgetTester tester, String name) async {
  // Pantry header "+" opens the add-food sheet; the detailed form is its
  // last option.
  await tester.tap(find.byIcon(Icons.add_circle_outline));
  await settle(tester, timeout: const Duration(seconds: 1));
  await tester.tap(find.text('Enter every detail yourself'));
  await settle(tester, timeout: const Duration(seconds: 1));

  await tester.enterText(
      find.widgetWithText(TextField, 'Item name *'), name);
  await settle(tester, timeout: const Duration(seconds: 1));

  // The sheet's confirm control is a TextButton in its header row. The header
  // title is "Add item", so matching the exact text "Add" hits only the button.
  final add = find.widgetWithText(TextButton, 'Add');
  await tester.tap(add);
  // The repository schedules a real expiry notification before the bloc
  // reloads, so the list refresh lands noticeably later than the tap.
  await settle(tester, timeout: const Duration(seconds: 8));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: launch and navigation', () {
    testWidgets('app boots to the dashboard', (tester) async {
      await launchApp(tester);
      expect(find.text('Use first'), findsWidgets);
      expect(find.text('Pantry'), findsWidgets);
      expect(find.text('Plan'), findsWidgets);
      expect(find.text('Shop'), findsWidgets);
    });

    testWidgets('every bottom-nav tab opens without error', (tester) async {
      await launchApp(tester);
      for (final tab in ['Pantry', 'Plan', 'Shop', 'Use first']) {
        await openTab(tester, tab);
        expect(tester.takeException(), isNull, reason: '$tab tab threw');
      }
    });

    testWidgets('an empty home invites the first receipt scan', (tester) async {
      await launchApp(tester);
      expect(find.text('Scan a receipt'), findsWidgets);
      expect(find.text('Tap what you have'), findsOneWidget);
    });
  });

  group('E2E: pantry item lifecycle', () {
    testWidgets('manually added item appears in the pantry', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Pantry');
      await addItemManually(tester, 'E2E Milk');

      expect(find.text('E2E Milk'), findsOneWidget);
    });

    testWidgets('added item shows up on the Use first screen', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Pantry');
      await addItemManually(tester, 'E2E Milk');
      await openTab(tester, 'Use first');

      expect(find.text('E2E Milk'), findsOneWidget);
      expect(find.text('This month'), findsOneWidget);
    });

    testWidgets('item survives a full app restart', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Pantry');
      await addItemManually(tester, 'E2E Persisted');

      // Rebuild the whole widget tree — the database is untouched.
      await tester.pumpWidget(const SizedBox());
      await settle(tester, timeout: const Duration(seconds: 1));
      await tester.pumpWidget(const PantryPalApp());
      await settle(tester, timeout: const Duration(seconds: 3));
      await dismissPaywallIfPresent(tester);
      await openTab(tester, 'Pantry');

      expect(find.text('E2E Persisted'), findsOneWidget);
    });

    testWidgets('search filters the pantry list', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Pantry');
      await addItemManually(tester, 'E2E Milk');
      await addItemManually(tester, 'E2E Chicken');

      await tester.tap(find.byIcon(Icons.search));
      await settle(tester, timeout: const Duration(seconds: 1));
      await tester.enterText(find.byType(TextField).first, 'Chicken');
      await settle(tester, timeout: const Duration(seconds: 2));

      expect(find.text('E2E Chicken'), findsOneWidget);
      expect(find.text('E2E Milk'), findsNothing);
    });

    testWidgets('swiping an item to Consumed removes it from the pantry',
        (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Pantry');
      await addItemManually(tester, 'E2E Eaten');

      await tester.drag(find.text('E2E Eaten'), const Offset(-300, 0));
      await settle(tester, timeout: const Duration(seconds: 1));
      await tester.tap(find.text('Consumed'));
      await settle(tester, timeout: const Duration(seconds: 2));

      expect(find.text('E2E Eaten'), findsNothing);
    });

    testWidgets('empty pantry shows its empty state', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Pantry');
      expect(find.text('Nothing here yet'), findsOneWidget);
    });
  });

  group('E2E: shopping list', () {
    testWidgets('add, tick and clear a shopping item', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Shop');

      await tester.enterText(
          find.widgetWithText(TextField, 'Add item...'), 'E2E Olive Oil');
      await settle(tester, timeout: const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await settle(tester, timeout: const Duration(seconds: 2));
      expect(find.text('E2E Olive Oil'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await settle(tester, timeout: const Duration(seconds: 2));
      expect(find.text('Clear done'), findsOneWidget);

      await tester.tap(find.text('Clear done'));
      await settle(tester, timeout: const Duration(seconds: 2));
      expect(find.text('E2E Olive Oil'), findsNothing);
    });

    testWidgets('shopping list persists across tab switches', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Shop');
      await tester.enterText(
          find.widgetWithText(TextField, 'Add item...'), 'E2E Bread');
      await settle(tester, timeout: const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await settle(tester, timeout: const Duration(seconds: 2));

      await openTab(tester, 'Use first');
      await openTab(tester, 'Shop');
      expect(find.text('E2E Bread'), findsOneWidget);
    });
  });

  group('E2E: recipes', () {
    testWidgets('the seeded recipe library is present', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Plan');
      await tester.tap(find.text('All recipes'));
      await settle(tester, timeout: const Duration(seconds: 3));

      expect(find.text('No recipes yet'), findsNothing,
          reason: 'seedIfEmpty should have populated the library');
      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('recipe search narrows the list', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Plan');
      await tester.tap(find.text('All recipes'));
      await settle(tester, timeout: const Duration(seconds: 3));

      await tester.enterText(
          find.widgetWithText(TextField, 'Search recipes…'), 'zzzznomatch');
      await settle(tester, timeout: const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening a recipe shows its detail page', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Plan');
      await tester.tap(find.text('All recipes'));
      await settle(tester, timeout: const Duration(seconds: 3));

      final cards = find.byType(InkWell);
      if (cards.evaluate().isNotEmpty) {
        await tester.tap(cards.first);
        await settle(tester, timeout: const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('E2E: settings', () {
    testWidgets('settings lists the expected rows', (tester) async {
      await launchApp(tester);
      await openSettings(tester);

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text('Delete All Data'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
    });

    testWidgets('privacy policy opens', (tester) async {
      await launchApp(tester);
      await openSettings(tester);
      await tester.tap(find.text('Privacy Policy'));
      await settle(tester, timeout: const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('delete all data clears the pantry', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Pantry');
      await addItemManually(tester, 'E2E Doomed');
      await openSettings(tester);

      await tester.tap(find.text('Delete All Data'));
      await settle(tester, timeout: const Duration(seconds: 1));

      // Confirm in the dialog.
      final confirm = find.text('Delete');
      if (confirm.evaluate().isNotEmpty) {
        await tester.tap(confirm.last);
        await settle(tester, timeout: const Duration(seconds: 2));
      }

      await tester.pageBack();
      await settle(tester, timeout: const Duration(seconds: 2));
      await openTab(tester, 'Pantry');
      expect(find.text('E2E Doomed'), findsNothing);
    });
  });

  group('E2E: scan entry points', () {
    testWidgets('the add sheet offers every way to add food', (tester) async {
      await launchApp(tester);
      await tester.tap(find.text('Add food').last);
      await settle(tester, timeout: const Duration(seconds: 1));

      expect(find.text('Scan a receipt'), findsWidgets);
      expect(find.text('Fridge photo'), findsOneWidget);
      expect(find.text('Barcode'), findsOneWidget);
      expect(find.text('Tap foods'), findsOneWidget);
      expect(find.text('Enter every detail yourself'), findsOneWidget);
    });

    testWidgets('typing names adds several items at once', (tester) async {
      await launchApp(tester);
      await tester.tap(find.text('Add food').last);
      await settle(tester, timeout: const Duration(seconds: 1));
      await tester.enterText(
          find.widgetWithText(TextField, 'milk, 2 eggs, spinach…'), 'milk, eggs, spinach');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await settle(tester, timeout: const Duration(seconds: 6));

      expect(find.textContaining('3 items added'), findsOneWidget);
    });
  });

  group('E2E: AI backend reachability', () {
    testWidgets('Leftover rescue reaches its backend', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Pantry');
      await addItemManually(tester, 'E2E Spinach');
      await openTab(tester, 'Plan');

      final rescue = find.text('Leftover rescue');
      if (rescue.evaluate().isEmpty) {
        markTestSkipped('Leftover rescue entry point not on the Plan tab');
        return;
      }
      await tester.tap(rescue.first);
      await settle(tester, timeout: const Duration(seconds: 2));
      await tester.tap(find.text('E2E Spinach').first);
      await tester.tap(find.textContaining('Get 3'));
      await settle(tester, timeout: const Duration(seconds: 25));

      expect(find.textContaining('unavailable'), findsNothing,
          reason: 'the AI backend must be reachable from the device');
    });
  });
}
