import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/scan/data/ai_scan_client.dart';
import 'package:pantrypal/features/scan/presentation/widgets/scan_results_view.dart';
import 'package:pantrypal/features/scan/presentation/widgets/scan_stage.dart';
import 'package:pantrypal/features/scan/presentation/widgets/scanning_view.dart';

Map<String, dynamic> it(String name,
        {String confidence = 'high', List<double>? box, double qty = 1, int days = 7}) =>
    {
      'id': 'id-$name',
      'name': name,
      'category': FoodCategory.dairy,
      'quantity': qty,
      'unit': 'item',
      'price': null,
      'estimatedExpiryDays': days,
      'confidence': confidence,
      'box': box,
    };

Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduceMotion),
        child: child,
      ),
    );

void main() {
  group('ScanResultsView', () {
    late List<Map<String, dynamic>> items;
    setUp(() => items = [it('Milk'), it('Eggs', qty: 6, days: 21), it('Mystery Jar', confidence: 'low')]);

    Widget view({
      Set<int> selected = const {0, 1},
      void Function(int)? onToggle,
      void Function(int, Map<String, dynamic>)? onEdit,
      void Function(int)? onRemove,
      VoidCallback? onAdd,
      bool offline = false,
    }) =>
        host(ScanResultsView(
          items: items,
          selected: selected,
          offline: offline,
          onToggle: onToggle ?? (_) {},
          onEdit: onEdit ?? (_, __) {},
          onRemove: onRemove ?? (_) {},
          onAdd: onAdd ?? () {},
          onRescan: () {},
        ));

    testWidgets('says how many were detected and separates doubtful items', (tester) async {
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();

      expect(find.text('3 items detected'), findsOneWidget);
      expect(find.text('PLEASE CHECK · 1'), findsOneWidget);
      expect(find.text('LOOKS RIGHT · 2'), findsOneWidget);
      expect(find.textContaining('1 item needs a quick check'), findsOneWidget);
      expect(find.text('Not sure — is this right?'), findsOneWidget);
    });

    testWidgets('the add button counts only what is ticked', (tester) async {
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(find.text('Add 2 items'), findsOneWidget);
    });

    testWidgets('nothing ticked disables adding', (tester) async {
      var added = false;
      await tester.pumpWidget(view(selected: {}, onAdd: () => added = true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select items to add'));
      expect(added, isFalse);
    });

    testWidgets('tapping a row toggles it', (tester) async {
      int? toggled;
      await tester.pumpWidget(view(onToggle: (i) => toggled = i));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Milk'));
      expect(toggled, 0);
    });

    testWidgets('shows quantity and shelf life at a glance', (tester) async {
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(find.text('×6 · ~3 weeks'), findsOneWidget);
      expect(find.text('~7 days'), findsWidgets);
    });

    testWidgets('quick edit: retype, confirm, and it comes back as a confident item', (tester) async {
      int? index;
      Map<String, dynamic>? changes;
      await tester.pumpWidget(view(onEdit: (i, c) {
        index = i;
        changes = c;
      }));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined).first); // the doubtful row is listed first
      await tester.pumpAndSettle();
      expect(find.text('What is it?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Miso Paste');
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(index, 2);
      expect(changes!['name'], 'Miso Paste');
      expect(changes!['confidence'], 'high');
    });

    testWidgets('edit sheet suggests known foods while typing and adopts their shelf life',
        (tester) async {
      Map<String, dynamic>? changes;
      await tester.pumpWidget(view(onEdit: (_, c) => changes = c));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'spin');
      await tester.pump();
      await tester.tap(find.textContaining('Spinach'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(changes!['name'], 'Spinach');
      expect(changes!['estimatedExpiryDays'], 4);
      expect(changes!['category'], FoodCategory.vegetables);
    });

    testWidgets('quantity stepper works and cannot go below 1', (tester) async {
      Map<String, dynamic>? changes;
      await tester.pumpWidget(view(onEdit: (_, c) => changes = c));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined).at(1));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(changes!['quantity'], 3.0);
    });

    testWidgets('swiping a row away removes it', (tester) async {
      int? removed;
      await tester.pumpWidget(view(onRemove: (i) => removed = i));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Milk'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(removed, 0);
    });

    testWidgets('offline results carry a plain warning', (tester) async {
      await tester.pumpWidget(view(offline: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('Offline'), findsOneWidget);
    });
  });

  group('ScanningView', () {
    Widget view(ScanPhase phase, List<Map<String, dynamic>> items,
            {ScanKind kind = ScanKind.fridge, bool reduce = false}) =>
        host(
          ScanningView(kind: kind, imagePath: '/none.jpg', phase: phase, items: items, onCancel: () {}),
          reduceMotion: reduce,
        );

    testWidgets('tells the truth about each stage', (tester) async {
      await tester.pumpWidget(view(ScanPhase.preparing, []));
      expect(find.text('Preparing your photo'), findsOneWidget);

      await tester.pumpWidget(view(ScanPhase.analyzing, []));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Looking through your fridge'), findsOneWidget);

      await tester.pumpWidget(view(ScanPhase.analyzing, [], kind: ScanKind.receipt));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Reading your receipt'), findsOneWidget);
    });

    testWidgets('items appear as they are found and the count follows', (tester) async {
      await tester.pumpWidget(view(ScanPhase.streaming, [it('Milk')]));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('1 item found'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);

      await tester.pumpWidget(view(ScanPhase.streaming, [it('Milk'), it('Eggs'), it('Cheese')]));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('3 items found'), findsOneWidget);
      expect(find.text('Eggs'), findsOneWidget);
    });

    testWidgets('a long list is summarised instead of overflowing', (tester) async {
      final many = [for (var i = 0; i < 20; i++) it('Food$i')];
      await tester.pumpWidget(view(ScanPhase.streaming, many));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('20 items found'), findsOneWidget);
      expect(find.text('+8 more'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancel is always available', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(host(ScanningView(
        kind: ScanKind.fridge,
        imagePath: '/none.jpg',
        phase: ScanPhase.analyzing,
        items: const [],
        onCancel: () => cancelled = true,
      )));
      await tester.tap(find.text('Cancel'));
      expect(cancelled, isTrue);
    });

    testWidgets('reduced motion still works', (tester) async {
      await tester.pumpWidget(view(ScanPhase.streaming, [it('Milk')], reduce: true));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('1 item found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ScanStage', () {
    Widget stage(List<Map<String, dynamic>> items, {bool active = true}) => host(Scaffold(
          body: SizedBox(
            width: 390,
            height: 500,
            child: ScanStage(imagePath: '/none.jpg', imageSize: const Size(300, 400), items: items, active: active),
          ),
        ));

    testWidgets('draws an outline and label only for items that have a box', (tester) async {
      await tester.pumpWidget(stage([
        it('Milk', box: [0.1, 0.4, 0.4, 0.8]),
        it('Eggs'), // no box: listed elsewhere, not drawn here
      ]));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Eggs'), findsNothing);
    });

    testWidgets('unsure items are marked with a question mark', (tester) async {
      await tester.pumpWidget(stage([it('Jar', confidence: 'low', box: [0.2, 0.4, 0.5, 0.7])]));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Jar ?'), findsOneWidget);
    });

    testWidgets('keeps the photo\'s own shape so boxes line up', (tester) async {
      await tester.pumpWidget(stage([]));
      await tester.pump();
      final box = tester.getSize(find.descendant(of: find.byType(ScanStage), matching: find.byType(SizedBox)).first);
      expect(box.width / box.height, closeTo(0.75, 0.01));
    });

    testWidgets('animations stop when the scan is done', (tester) async {
      await tester.pumpWidget(stage([], active: false));
      await tester.pumpAndSettle(); // would hang if the beam kept repeating
    });
  });
}
