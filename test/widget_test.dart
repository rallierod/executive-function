import 'package:flutter_test/flutter_test.dart';

import 'package:executive_function/app.dart';

void main() {
  testWidgets('navigation shell renders expected tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const ExecutiveFunctionApp());

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Money'), findsOneWidget);
    expect(find.text('Closet'), findsOneWidget);
  });
}
