import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/main.dart';

void main() {
  testWidgets('app bootstraps', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GreyEyeApp()));
    await tester.pumpAndSettle();

    expect(find.byType(GreyEyeApp), findsOneWidget);
  });
}
