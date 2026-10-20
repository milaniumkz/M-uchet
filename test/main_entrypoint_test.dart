import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/main.dart' as entrypoint;

void main() {
  testWidgets('default application opens REST login without Firebase bootstrap', (tester) async {
    entrypoint.main();
    await tester.pumpAndSettle();
    expect(find.text('Вход в М-Учёт'),findsOneWidget);
    expect(find.byType(TextField),findsNWidgets(2));
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
