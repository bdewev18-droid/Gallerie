import 'package:flutter_test/flutter_test.dart';
import 'package:gallerie/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GallerieApp());
    expect(find.byType(GallerieApp), findsOneWidget);
  });
}
