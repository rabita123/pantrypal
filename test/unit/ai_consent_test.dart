import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/scan/data/ai_scan_client.dart';
import 'package:pantrypal/features/scan/data/scan_bloc.dart';
import 'package:pantrypal/shared/services/ai_consent.dart';

import '../support/plugin_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => stubSharedPreferences());

  test('nothing is decided until the user chooses', () async {
    expect(await AiConsent.current(), isNull);
  });

  test('the choice is remembered and can be changed', () async {
    await AiConsent.set(true);
    expect(await AiConsent.current(), isTrue);
    await AiConsent.set(false);
    expect(await AiConsent.current(), isFalse);
  });

  test('without AI permission a scan never calls the AI', () async {
    var called = false;
    final bloc = ScanBloc(
      useAi: false,
      scanner: (_, __) {
        called = true;
        return Stream.value(const ScanUpdate(ScanPhase.done));
      },
    );
    bloc.add(ScanImageSelected('/does/not/exist.jpg'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(called, isFalse, reason: 'the photo must not leave the phone');
    await bloc.close();
  });

  test('with AI permission the scan uses the AI', () async {
    var called = false;
    final bloc = ScanBloc(
      kind: ScanKind.fridge,
      scanner: (_, __) {
        called = true;
        return Stream.value(const ScanUpdate(ScanPhase.done));
      },
    );
    bloc.add(ScanImageSelected('/tmp/x.jpg'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(called, isTrue);
    await bloc.close();
  });
}
