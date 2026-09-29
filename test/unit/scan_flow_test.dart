import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/scan/data/ai_scan_client.dart';
import 'package:pantrypal/features/scan/data/scan_bloc.dart';

Map<String, dynamic> found(String name, {String confidence = 'high'}) => {
      'id': 'id-$name',
      'name': name,
      'category': FoodCategory.dairy,
      'quantity': 1.0,
      'unit': 'item',
      'price': null,
      'estimatedExpiryDays': 7,
      'confidence': confidence,
      'box': null,
    };

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('progress flows through the bloc and ends at review with doubtful items unticked', () async {
    final bloc = ScanBloc(
      kind: ScanKind.fridge,
      scanner: (_, __) => Stream.fromIterable([
        const ScanUpdate(ScanPhase.preparing),
        const ScanUpdate(ScanPhase.analyzing, imageSize: Size(100, 80)),
        ScanUpdate(ScanPhase.streaming, items: [found('Milk')]),
        ScanUpdate(ScanPhase.streaming, items: [found('Milk'), found('Jar', confidence: 'low')]),
        ScanUpdate(ScanPhase.done, items: [found('Milk'), found('Jar', confidence: 'low')]),
      ]),
    );
    final seen = <ScanState>[];
    final sub = bloc.stream.listen(seen.add);

    bloc.add(ScanImageSelected('/tmp/p.jpg'));
    await settle();

    final streaming = seen.whereType<ScanStreaming>().toList();
    expect(streaming.map((s) => s.items.length), containsAllInOrder([0, 1, 2]));
    expect(streaming.last.imagePath, '/tmp/p.jpg');

    final review = seen.last as ScanReviewReady;
    expect(review.parsedItems.length, 2);
    expect(review.selectedIndices, {0}, reason: 'the low-confidence jar must not be pre-ticked');
    expect(review.imagePath, '/tmp/p.jpg');

    await sub.cancel();
    await bloc.close();
  });

  test('a fridge scan that finds nothing ends in a readable error', () async {
    final bloc = ScanBloc(
      kind: ScanKind.fridge,
      scanner: (_, __) => Stream.fromIterable([const ScanUpdate(ScanPhase.done)]),
    );
    bloc.add(ScanImageSelected('/tmp/p.jpg'));
    await settle();
    expect(bloc.state, isA<ScanError>());
    expect((bloc.state as ScanError).message, contains('No food items'));
    await bloc.close();
  });

  test('a fridge scan failure shows the reason, not a crash', () async {
    final bloc = ScanBloc(
      kind: ScanKind.fridge,
      scanner: (_, __) => Stream.error(Exception('boom')),
    );
    bloc.add(ScanImageSelected('/tmp/p.jpg'));
    await settle();
    expect(bloc.state, isA<ScanError>());
    await bloc.close();
  });

  test('cancelling mid-scan stops updates from reaching the screen', () async {
    final controller = StreamController<ScanUpdate>();
    final bloc = ScanBloc(kind: ScanKind.fridge, scanner: (_, __) => controller.stream);
    bloc.add(ScanImageSelected('/tmp/p.jpg'));
    await settle();
    expect(bloc.state, isA<ScanStreaming>());

    bloc.add(ScanReset());
    await settle();
    expect(bloc.state, isA<ScanIdle>());

    // The abandoned scan finishes late — it must not resurrect the screen.
    controller.add(ScanUpdate(ScanPhase.done, items: [found('Milk')]));
    await settle();
    expect(bloc.state, isA<ScanIdle>());
    expect(controller.hasListener, isFalse, reason: 'the request is cancelled too');

    await controller.close();
    await bloc.close();
  });

  test('starting a second scan supersedes the first', () async {
    final first = StreamController<ScanUpdate>();
    var call = 0;
    final bloc = ScanBloc(
      kind: ScanKind.fridge,
      scanner: (_, __) => call++ == 0
          ? first.stream
          : Stream.value(ScanUpdate(ScanPhase.done, items: [found('Eggs')])),
    );
    bloc.add(ScanImageSelected('/tmp/one.jpg'));
    await settle();
    bloc.add(ScanImageSelected('/tmp/two.jpg'));
    await settle();

    first.add(ScanUpdate(ScanPhase.done, items: [found('Stale')]));
    await settle();

    final s = bloc.state as ScanReviewReady;
    expect(s.parsedItems.single['name'], 'Eggs');
    expect(s.imagePath, '/tmp/two.jpg');
    await first.close();
    await bloc.close();
  });
}
