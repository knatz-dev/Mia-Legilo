import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('device procedure is documented and this file does not fake a pass', (
    tester,
  ) async {
    // This does not pass a behavior check. It is skipped so a green
    // `flutter test` run cannot be quoted as device evidence.
    markTestSkipped(
      'Physical Android procedure is scripts/device_benchmark.md. '
      'Widget coverage for epub_rtl is test/epub_rtl_scroll_test.dart.',
    );
  });
}
