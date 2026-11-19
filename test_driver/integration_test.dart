import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves every screenshot taken by integration_test/app_flow_test.dart
/// into evidence/screenshots/ on the machine running `flutter drive`.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = await File('evidence/screenshots/$name.png').create(recursive: true);
      file.writeAsBytesSync(bytes);
      return true;
    },
  );
}
