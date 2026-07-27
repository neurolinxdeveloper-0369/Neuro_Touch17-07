import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:neuro_touch/app.dart';
import 'package:neuro_touch/data/services/storage_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Disable Google Fonts runtime fetching in tests to use bundled assets
    GoogleFonts.config.allowRuntimeFetching = false;

    // Mock path_provider Method Channel
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '.';
      }
      return null;
    });

    // Mock flutter_secure_storage Method Channel
    const MethodChannel('plugins.it_ces.com/secure_storage')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      return null;
    });

    await StorageService.init();
  });

  testWidgets('Neuro Touch app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(child: NeuroTouchApp()),
    );

    // Allow splash screen navigation timer to complete
    await tester.pump(const Duration(seconds: 3));

    // Just verify the app renders without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
