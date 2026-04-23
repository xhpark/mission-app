import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_app/core/widgets/interactive_learning_screen.dart';

void main() {
  testWidgets('primary button disabled after timer expires', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InteractiveLearningScreen(
          title: '테스트',
          subtitle: '서브',
          progress: 0.2,
          progressLabel: '1 / 5',
          promptTitle: '문제',
          foreignText: 'สวัสดี',
          nativeText: '안녕하세요',
          pronunciation: 'sa-wat-dee',
          hint: '힌트',
          primaryButtonLabel: '다음',
          primaryRoute: '/next',
          timeLimitSeconds: 1,
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.textContaining('남은 시간 0초'), findsOneWidget);
  });
}
