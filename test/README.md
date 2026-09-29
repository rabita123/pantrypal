# PantryPal test harness

Four layers, each runnable on its own.

| Layer | Location | Needs | Runtime |
| --- | --- | --- | --- |
| Unit | `test/unit/` | nothing | ~10s |
| Widget | `test/widget/` | nothing | ~10s |
| Backend contract | `test/unit/backend_connectivity_test.dart` (tag `network`) | internet | ~5s |
| End-to-end | `integration_test/app_test.dart` | a device | ~5min |

## Running

```bash
tool/run_tests.sh              # unit + widget (offline, deterministic)
tool/run_tests.sh --network    # + live Supabase contract checks
tool/run_tests.sh --e2e        # + end-to-end on a device
tool/run_tests.sh --all        # everything
```

Results land in `test_reports/` as raw `--reporter=json` plus a generated
`.md` summary per suite.

### End-to-end on a wirelessly tethered iPhone

`flutter test` cannot attach over wireless, so use the driver:

```bash
flutter drive --driver=test_driver/integration_test.dart \
              --target=integration_test/app_test.dart \
              -d <device-id> --publish-port
```

Simulators do not work on this machine: MLKit and mobile_scanner ship no
arm64 simulator slices, and macOS 26 no longer runs x86_64 simulator builds.
A physical device is the only E2E target.

## Support code

- `test/support/fixtures.dart` — item/recipe builders and raw OCR receipt samples.
- `test/support/test_db.dart` — per-file SQLite isolation. `flutter test` runs
  files concurrently and `DatabaseHelper` uses one fixed path, so each suite
  gets its own temp directory.
- `test/support/plugin_stubs.dart` — method-channel stubs for notifications and
  the home-widget bridge, so production code paths run unmocked.
- `test/support/di.dart` — GetIt registration for pages that resolve `sl<…>()`
  directly.

## Conventions

- Tests assert user-visible behaviour, not implementation details.
- A failing test means the app is wrong, not that the test needs relaxing.
  Tests currently failing are tracked as known defects — see the test report.
- Anything touching the network carries `tags: 'network'` so the default run
  stays offline and deterministic.
