// Driver entry point for `flutter drive`.
//
// Needed for wirelessly tethered iOS devices, where `flutter test` cannot
// attach to the VM service and `--publish-port` is only available on drive.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
