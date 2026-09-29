// The pantry card is the app's densest piece of information: name, quantity,
// expiry copy and a colour-coded status. These tests pin what a user sees.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/widgets/pantry_item_card.dart';

import '../support/fixtures.dart';

Future<void> pumpCard(
  WidgetTester tester,
  PantryItem model, {
  VoidCallback? onConsumed,
  VoidCallback? onWasted,
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PantryItemCard(
        item: model,
        onTap: onTap,
        onConsumed: onConsumed,
        onWasted: onWasted,
      ),
    ),
  ));
}

void main() {
  group('Content', () {
    testWidgets('shows the item name', (tester) async {
      await pumpCard(tester, item(name: 'Greek Yogurt'));
      expect(find.text('Greek Yogurt'), findsOneWidget);
    });

    testWidgets('shows a short countdown badge for a fresh item', (tester) async {
      await pumpCard(tester, item(name: 'Milk', daysFromNow: 9));
      expect(find.text('9 days'), findsOneWidget);
    });

    testWidgets('singularises the badge at one day left', (tester) async {
      await pumpCard(tester, item(daysFromNow: 1));
      expect(find.text('1 day'), findsOneWidget);
    });

    testWidgets('shows an urgent badge for an item expiring today', (tester) async {
      await pumpCard(tester, item(daysFromNow: 0));
      expect(find.text('Today!'), findsOneWidget);
    });

    testWidgets('badges an expired item as Expired', (tester) async {
      await pumpCard(tester, item(daysFromNow: -2));
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('shows quantity, unit and price when present', (tester) async {
      await pumpCard(tester,
          item(name: 'Milk', quantity: 2, unit: 'L', price: 3.49));
      expect(find.text('2 L'), findsOneWidget);
      expect(find.text('\$3.49'), findsOneWidget);
    });

    testWidgets('omits the price when the item has none', (tester) async {
      await pumpCard(tester, item(price: null));
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('shows the storage location', (tester) async {
      await pumpCard(tester, item(location: StorageLocation.freezer));
      expect(find.text('Freezer'), findsOneWidget);
    });

    testWidgets('renders a long name without overflowing', (tester) async {
      await pumpCard(
          tester, item(name: 'Organic Free Range Grass Fed Whole Milk 2 Litre'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders every category without error', (tester) async {
      for (final c in FoodCategory.values) {
        await pumpCard(tester, item(name: c.label, category: c));
        expect(tester.takeException(), isNull, reason: 'category ${c.name}');
      }
    });
  });

  group('Status indication', () {
    testWidgets('uses distinct status icons per expiry state', (tester) async {
      await pumpCard(tester, item(daysFromNow: 30));
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      await pumpCard(tester, item(daysFromNow: 2));
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

      await pumpCard(tester, item(daysFromNow: -1));
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });
  });

  group('Interaction', () {
    testWidgets('tapping the card invokes onTap', (tester) async {
      var tapped = false;
      await pumpCard(tester, item(), onTap: () => tapped = true);
      await tester.tap(find.byType(PantryItemCard));
      expect(tapped, isTrue);
    });

    testWidgets('swiping reveals Consumed and Wasted actions', (tester) async {
      await pumpCard(tester, item(name: 'Milk'), onConsumed: () {}, onWasted: () {});

      await tester.drag(find.byType(PantryItemCard), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(find.text('Consumed'), findsOneWidget);
      expect(find.text('Wasted'), findsOneWidget);
    });

    testWidgets('tapping Consumed fires the callback', (tester) async {
      var consumed = false;
      await pumpCard(tester, item(), onConsumed: () => consumed = true, onWasted: () {});

      await tester.drag(find.byType(PantryItemCard), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Consumed'));
      await tester.pumpAndSettle();

      expect(consumed, isTrue);
    });

    testWidgets('tapping Wasted fires the callback', (tester) async {
      var wasted = false;
      await pumpCard(tester, item(), onConsumed: () {}, onWasted: () => wasted = true);

      await tester.drag(find.byType(PantryItemCard), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wasted'));
      await tester.pumpAndSettle();

      expect(wasted, isTrue);
    });
  });
}
