import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/core/widgets/interactive_learning_screen.dart';

void main() {
  Widget buildHarness(InteractiveLearningScreen screen) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => screen),
        GoRoute(path: '/next', builder: (context, state) => const SizedBox()),
      ],
    );
    return MaterialApp.router(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      routerConfig: router,
    );
  }

  testWidgets('primary button disabled after timer expires', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        const InteractiveLearningScreen(
          title: 'Test',
          subtitle: 'Subtitle',
          progress: 0.2,
          progressLabel: '1 / 5',
          promptTitle: 'Prompt',
          foreignText: 'sawatdee',
          nativeText: 'Hello',
          pronunciation: 'sa-wat-dee',
          hint: 'Hint',
          primaryButtonLabel: 'Next',
          primaryRoute: '/next',
          timeLimitSeconds: 1,
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.textContaining('Remaining'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('auto-advance policy invokes timeout action once', (
    tester,
  ) async {
    var calledCount = 0;
    InteractivePrimaryPayload? payload;
    await tester.pumpWidget(
      buildHarness(
        InteractiveLearningScreen(
          title: 'Test',
          subtitle: 'Subtitle',
          progress: 0.2,
          progressLabel: '1 / 5',
          promptTitle: 'Prompt',
          foreignText: 'sawatdee',
          nativeText: 'Hello',
          pronunciation: 'sa-wat-dee',
          hint: 'Hint',
          primaryButtonLabel: 'Next',
          primaryRoute: '/next',
          options: const ['A', 'B', 'C', 'D'],
          correctOptionIndex: 0,
          timeLimitSeconds: 1,
          choiceTimeoutBehavior: ChoiceTimeoutBehavior.autoAdvanceAsWrong,
          onPrimaryAction: (p) async {
            calledCount += 1;
            payload = p;
            return null;
          },
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(calledCount, 1);
    expect(payload?.timedOut, isTrue);
    expect(payload?.selectedIndex, isNull);
  });

  testWidgets('retry timeout keeps primary next action available', (
    tester,
  ) async {
    var calledCount = 0;
    InteractivePrimaryPayload? payload;

    await tester.pumpWidget(
      buildHarness(
        InteractiveLearningScreen(
          title: 'Test',
          subtitle: 'Subtitle',
          progress: 0.2,
          progressLabel: '1 / 5',
          promptTitle: 'Prompt',
          foreignText: 'sawatdee',
          nativeText: 'Hello',
          pronunciation: 'sa-wat-dee',
          hint: 'Hint',
          primaryButtonLabel: 'Next',
          primaryRoute: '/next',
          options: const ['A', 'B', 'C', 'D'],
          correctOptionIndex: 0,
          timeLimitSeconds: 1,
          choiceTimeoutBehavior: ChoiceTimeoutBehavior.retrySameQuestion,
          onPrimaryAction: (p) async {
            calledCount += 1;
            payload = p;
            return null;
          },
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    expect(calledCount, 1);
    expect(payload?.timedOut, isTrue);
    expect(payload?.selectedIndex, isNull);
  });

  testWidgets(
    'retry timeout preserves selected answer on primary next action',
    (tester) async {
      var calledCount = 0;
      InteractivePrimaryPayload? payload;

      await tester.pumpWidget(
        buildHarness(
          InteractiveLearningScreen(
            title: 'Test',
            subtitle: 'Subtitle',
            progress: 0.2,
            progressLabel: '1 / 5',
            promptTitle: 'Prompt',
            foreignText: 'sawatdee',
            nativeText: 'Hello',
            pronunciation: 'sa-wat-dee',
            hint: 'Hint',
            primaryButtonLabel: 'Next',
            primaryRoute: '/next',
            options: const ['A', 'B', 'C', 'D'],
            correctOptionIndex: 2,
            timeLimitSeconds: 1,
            choiceTimeoutBehavior: ChoiceTimeoutBehavior.retrySameQuestion,
            allowAnyOptionToProceed: true,
            onPrimaryAction: (p) async {
              calledCount += 1;
              payload = p;
              return null;
            },
          ),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -520));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'C'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();

      expect(calledCount, 1);
      expect(payload?.timedOut, isTrue);
      expect(payload?.selectedIndex, 2);
      expect(payload?.correctOptionIndex, 2);
    },
  );

  testWidgets(
    'speaking timeout without recording advances as unanswered attempt',
    (tester) async {
      var calledCount = 0;
      InteractivePrimaryPayload? payload;

      await tester.pumpWidget(
        buildHarness(
          InteractiveLearningScreen(
            title: 'Test',
            subtitle: 'Subtitle',
            progress: 0.2,
            progressLabel: '1 / 5',
            promptTitle: 'Prompt',
            foreignText: 'sawatdee',
            nativeText: 'Hello',
            pronunciation: 'sa-wat-dee',
            hint: 'Hint',
            primaryButtonLabel: 'Next',
            primaryRoute: '/next',
            showMicSection: true,
            timeLimitSeconds: 1,
            choiceTimeoutBehavior: ChoiceTimeoutBehavior.autoAdvance,
            onPrimaryAction: (p) async {
              calledCount += 1;
              payload = p;
              return null;
            },
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(calledCount, 1);
      expect(payload?.timedOut, isTrue);
      expect(payload?.speakingTimedOutWithoutRecording, isTrue);
    },
  );

  testWidgets('speaking timeout stops active recording before advancing', (
    tester,
  ) async {
    var primaryCalledCount = 0;
    var stopCalledCount = 0;

    await tester.pumpWidget(
      buildHarness(
        InteractiveLearningScreen(
          title: 'Test',
          subtitle: 'Subtitle',
          progress: 0.2,
          progressLabel: '1 / 5',
          promptTitle: 'Prompt',
          foreignText: 'sawatdee',
          nativeText: 'Hello',
          pronunciation: 'sa-wat-dee',
          hint: 'Hint',
          primaryButtonLabel: 'Next',
          primaryRoute: '/next',
          showMicSection: true,
          recordStartLabel: 'Start recording',
          recordStopLabel: 'Stop recording',
          timeLimitSeconds: 1,
          choiceTimeoutBehavior: ChoiceTimeoutBehavior.autoAdvance,
          onStartRecording: () async {},
          onStopRecordingAndValidate: () async {
            stopCalledCount += 1;
            return const SpeakingValidationResult(
              hasRecording: true,
              passed: false,
              similarityScore: 30,
            );
          },
          onPrimaryAction: (_) async {
            primaryCalledCount += 1;
            return null;
          },
        ),
      ),
    );

    final recordButton = find.widgetWithText(ElevatedButton, 'Start recording');
    await tester.ensureVisible(recordButton);
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pump();
    await tester.tap(recordButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(stopCalledCount, 1);
    expect(primaryCalledCount, 1);
  });

  testWidgets('app background pauses timer and invokes lifecycle callback', (
    tester,
  ) async {
    var backgroundCalled = 0;
    var primaryCalled = 0;

    await tester.pumpWidget(
      buildHarness(
        InteractiveLearningScreen(
          title: 'Test',
          subtitle: 'Subtitle',
          progress: 0.2,
          progressLabel: '1 / 5',
          promptTitle: 'Prompt',
          foreignText: 'sawatdee',
          nativeText: 'Hello',
          pronunciation: 'sa-wat-dee',
          hint: 'Hint',
          primaryButtonLabel: 'Next',
          primaryRoute: '/next',
          timeLimitSeconds: 3,
          choiceTimeoutBehavior: ChoiceTimeoutBehavior.autoAdvance,
          onAppBackgrounded: () async {
            backgroundCalled += 1;
          },
          onPrimaryAction: (_) async {
            primaryCalled += 1;
            return null;
          },
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(backgroundCalled, 1);
    expect(primaryCalled, 0);
  });

  testWidgets('record stop automatically starts speaking review validation', (
    tester,
  ) async {
    var stopCalledCount = 0;
    var reviewCalledCount = 0;

    await tester.pumpWidget(
      buildHarness(
        InteractiveLearningScreen(
          title: 'Test',
          subtitle: 'Subtitle',
          progress: 0.2,
          progressLabel: '1 / 5',
          promptTitle: 'Prompt',
          foreignText: 'sawatdee',
          nativeText: 'Hello',
          pronunciation: 'sa-wat-dee',
          hint: 'Hint',
          primaryButtonLabel: 'Next',
          primaryRoute: '/next',
          showMicSection: true,
          recordStartLabel: 'Start recording',
          recordStopLabel: 'Stop recording',
          myRecordingReviewLabel: 'Review similarity',
          revealSpeakingResultOnReviewTap: true,
          onStartRecording: () async {},
          onStopRecordingOnly: () async {
            stopCalledCount += 1;
            return const SpeakingValidationResult(
              hasRecording: true,
              passed: false,
              message: 'Recording completed.',
            );
          },
          onReviewRecordingAndValidate: () async {
            reviewCalledCount += 1;
            return const SpeakingValidationResult(
              hasRecording: true,
              passed: true,
              similarityScore: 88,
              transcript: 'sawatdee',
              message: 'Review completed.',
            );
          },
        ),
      ),
    );

    final startButton = find.widgetWithText(ElevatedButton, 'Start recording');
    await tester.ensureVisible(startButton);
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pump();
    await tester.tap(startButton);
    await tester.pump();

    final stopButton = find.widgetWithText(ElevatedButton, 'Stop recording');
    await tester.tap(stopButton);
    await tester.pump();

    expect(stopCalledCount, 1);
    expect(reviewCalledCount, 1);
    expect(
      find.widgetWithText(OutlinedButton, 'Review similarity'),
      findsOneWidget,
    );
    expect(find.textContaining('88'), findsOneWidget);
  });

  testWidgets(
    'recording timeout automatically starts speaking review validation',
    (tester) async {
      var stopCalledCount = 0;
      var reviewCalledCount = 0;

      await tester.pumpWidget(
        buildHarness(
          InteractiveLearningScreen(
            title: 'Test',
            subtitle: 'Subtitle',
            progress: 0.2,
            progressLabel: '1 / 5',
            promptTitle: 'Prompt',
            foreignText: 'sawatdee',
            nativeText: 'Hello',
            pronunciation: 'sa-wat-dee',
            hint: 'Hint',
            primaryButtonLabel: 'Next',
            primaryRoute: '/next',
            showMicSection: true,
            recordStartLabel: 'Start recording',
            recordStopLabel: 'Stop recording',
            recordingTimeLimitSeconds: 1,
            myRecordingReviewLabel: 'Review similarity',
            revealSpeakingResultOnReviewTap: true,
            onStartRecording: () async {},
            onStopRecordingOnly: () async {
              stopCalledCount += 1;
              return const SpeakingValidationResult(
                hasRecording: true,
                passed: false,
                message: 'Recording completed.',
              );
            },
            onReviewRecordingAndValidate: () async {
              reviewCalledCount += 1;
              return const SpeakingValidationResult(
                hasRecording: true,
                passed: true,
                similarityScore: 90,
                transcript: 'sawatdee',
                message: 'Review completed.',
              );
            },
          ),
        ),
      );

      final startButton = find.widgetWithText(
        ElevatedButton,
        'Start recording',
      );
      await tester.ensureVisible(startButton);
      await tester.drag(find.byType(ListView), const Offset(0, -240));
      await tester.pump();
      await tester.tap(startButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(stopCalledCount, 1);
      expect(reviewCalledCount, 1);
      expect(find.textContaining('90'), findsOneWidget);
    },
  );
}
