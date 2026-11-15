import 'package:flutter_test/flutter_test.dart';
import 'package:instaadblocker/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const InstaAdBlockerApp());
    expect(find.text('InstaAdBlocker'), findsWidgets);
  });
}
