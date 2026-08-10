import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumenclaim/main.dart';

void main() {
  testWidgets('LumenClaim boots to the main menu', (WidgetTester tester) async {
    await tester.pumpWidget(const LumenClaimApp());

    // Title screen should show the game name and a PLAY button.
    expect(find.text('LUMENCLAIM'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
  });
}
