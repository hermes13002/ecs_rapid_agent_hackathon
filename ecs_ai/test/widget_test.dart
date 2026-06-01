import 'package:flutter_test/flutter_test.dart';

import 'package:ecs_ai/app/app.dart';

void main() {
  testWidgets('app renders workspace', (WidgetTester tester) async {
    await tester.pumpWidget(const EcsApp());
    expect(find.text('ECS AI'), findsOneWidget);
  });
}
