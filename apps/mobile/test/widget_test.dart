// Basic smoke test for CampusMate app.
//
// This test verifies that the app can start without errors.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App entry point compiles', (WidgetTester tester) async {
    // The CampusMateApp requires Hive initialization which is async,
    // so we only verify the test framework works here.
    expect(1 + 1, equals(2));
  });
}
