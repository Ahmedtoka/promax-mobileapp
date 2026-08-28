import 'package:flutter_test/flutter_test.dart';

import 'package:sales_rep_app/main.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PromaxApp());

    expect(find.text('PROMAX'), findsOneWidget);
    expect(find.text('دخول'), findsOneWidget);
    expect(find.text('الإيميل أو كود الموظف'), findsOneWidget);
  });
}
