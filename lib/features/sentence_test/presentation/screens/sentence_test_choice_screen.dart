import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/services/audio_player_service.dart';
import '../../../../core/widgets/interactive_learning_screen.dart';
import '../../../learning_content/data/thai_learning_content.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/domain/test_item_order.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';

class SentenceTestChoiceScreen extends ConsumerStatefulWidget {
  const SentenceTestChoiceScreen({super.key});

  @override
  ConsumerState<SentenceTestChoiceScreen> createState() =>
      _SentenceTestChoiceScreenState();
}

class _SentenceTestChoiceScreenState
    extends ConsumerState<SentenceTestChoiceScreen> {
  late final AudioPlayerService _audioPlayerService;

  @override
  void initState() {
    super.initState();
    _audioPlayerService = AudioPlayerService();
  }

  @override
  void dispose() {
    _audioPlayerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentStudySessionProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    final developmentSession = ref.watch(developmentSessionProvider);
    final flow = ref.watch(studyFlowControllerProvider);
    final category = session?.category.name ?? 'daily';
    final sentences = sentencesByCategory(category);
    final effectiveTotal =
        flow.totalItems > 0 && flow.totalItems < sentences.length
        ? flow.totalItems
        : sentences.length;
    final maxIndex = effectiveTotal > 0 ? effectiveTotal - 1 : 0;
    final targetIndexRaw = flow.indexOf(StudyFlowTrack.sentenceTestChoice);
    final displayIndex = targetIndexRaw > maxIndex ? maxIndex : targetIndexRaw;
    final targetIndex = resolveTestContentIndex(
      displayIndex: displayIndex,
      itemCount: effectiveTotal,
      levelName: session?.level.name,
      seedKey: session?.sessionId ?? 'dev',
      orderKey: 'sentence-test',
    );
    final hasNextInChoice = displayIndex < maxIndex;
    final timeLimitSeconds = switch (session?.level.name ?? 'beginner') {
      'intermediate' => 10,
      'advanced' => 8,
      _ => 12,
    };
    final target = sentenceAt(category, targetIndex);
    final choice = sentenceThaiOptions(
      category: category,
      correctIndex: targetIndex,
      seedKey: session?.sessionId ?? 'dev',
    );
    final optionLabels = choice.options
        .asMap()
        .entries
        .map(
          (entry) => _formatSentenceOptionLabel(
            category: category,
            thaiText: entry.value,
            sentenceId: choice.optionIdAt(entry.key),
          ),
        )
        .toList();
    final optionAudioPaths = choice.options
        .asMap()
        .entries
        .map(
          (entry) => choice.audioPathAt(
            entry.key,
            fallback: _findSentenceAudioPath(
              category: category,
              thaiText: entry.value,
              sentenceId: choice.optionIdAt(entry.key),
              fallbackAudioPath: target.audioPath,
            ),
          ),
        )
        .toList();

    return InteractiveLearningScreen(
      title: l10n?.sentenceTestChoiceTitle ?? 'Sentence Test - Choice',
      subtitle:
          l10n?.sentenceTestChoiceSubtitle ??
          'Select the Thai sentence that matches Korean.',
      progress: effectiveTotal <= 0 ? 0 : ((displayIndex + 1) / effectiveTotal),
      progressLabel:
          l10n?.sentenceTestChoiceProgressLabel(
            displayIndex + 1,
            effectiveTotal,
          ) ??
          'Question ${displayIndex + 1} / $effectiveTotal',
      promptTitle: '한국어 제시문에 해당하는 보기 문장을 선택하세요',
      foreignText: target.koreanText,
      nativeText: target.englishText,
      pronunciation: '${target.phonetic} / ${target.hangulPronunciation}',
      hint: formatThaiTokensForLearners(target.hint),
      options: optionLabels,
      correctOptionIndex: choice.correctIndex,
      showPromptDescription: false,
      showNativeText: false,
      showPromptInfoChips: false,
      showAudioSection: false,
      showChoiceFeedback: false,
      allowAnyOptionToProceed: true,
      showProgressAtBottom: true,
      showBlockedTimeLimitBar: false,
      showBlockedStatusBanner: false,
      primaryButtonLabel: hasNextInChoice
          ? '다음 문장 테스트'
          : (l10n?.sentenceTestChoicePrimaryButton ?? '말하기 테스트로 이동'),
      primaryRoute: '/sentence-test/speaking',
      showBackButton: true,
      backFallbackRoute: '/select',
      timeLimitSeconds: timeLimitSeconds,
      choiceTimeoutBehavior: ChoiceTimeoutBehavior.retrySameQuestion,
      onAppBackgrounded: _stopAudioForLifecycle,
      onAppResumed: _stopAudioForLifecycle,
      onOptionSelected: (index, _) {
        final audioPath = index < optionAudioPaths.length
            ? optionAudioPaths[index]
            : '';
        if (audioPath.isEmpty) {
          throw StateError('No sentence option audio path for index $index');
        }
        return _audioPlayerService.playAsset(audioPath);
      },
      onScreenOpened: () async {
        if (session == null ||
            user == null ||
            user.isAnonymous ||
            developmentSession) {
          return;
        }
        await ref
            .read(sessionRuntimeRepositoryProvider)
            .saveResumeState(
              userId: user.uid,
              sessionId: session.sessionId,
              route: '/sentence-test/choice',
            );
      },
      onPrimaryAction: (payload) async {
        final hasNext = ref
            .read(studyFlowControllerProvider.notifier)
            .advanceTrack(
              track: StudyFlowTrack.sentenceTestChoice,
              totalCount: effectiveTotal,
              isCorrectAttempt:
                  (payload.selectedIndex ?? -1) ==
                  (payload.correctOptionIndex ?? -2),
              countAsAttempt: true,
            );
        if (session == null ||
            user == null ||
            user.isAnonymous ||
            developmentSession) {
          return hasNext ? '/sentence-test/choice' : '/sentence-test/speaking';
        }
        await ref
            .read(sessionRuntimeRepositoryProvider)
            .submitChoiceTestItem(
              userId: user.uid,
              sessionId: session.sessionId,
              itemId: target.id,
              selectedItemId: choice.optionIdAt(payload.selectedIndex ?? -1),
              selectedIndex: payload.selectedIndex ?? -1,
              correctIndex: payload.correctOptionIndex ?? 0,
              elapsedSeconds: payload.elapsedSeconds,
            );
        await ref
            .read(sessionRuntimeRepositoryProvider)
            .saveResumeState(
              userId: user.uid,
              sessionId: session.sessionId,
              route: hasNext
                  ? '/sentence-test/choice'
                  : '/sentence-test/speaking',
            );
        return hasNext ? '/sentence-test/choice' : '/sentence-test/speaking';
      },
    );
  }

  Future<void> _stopAudioForLifecycle() {
    return _audioPlayerService.stop();
  }
}

String _formatSentenceOptionLabel({
  required String category,
  required String thaiText,
  String sentenceId = '',
}) {
  final sentence = _findSentenceOption(
    category: category,
    thaiText: thaiText,
    sentenceId: sentenceId,
  );
  final hangul = sentence?.hangulPronunciation.trim() ?? '';
  if (hangul.isEmpty) {
    return thaiText;
  }
  return '$hangul ($thaiText)';
}

String _findSentenceAudioPath({
  required String category,
  required String thaiText,
  required String fallbackAudioPath,
  String sentenceId = '',
}) {
  final sentence = _findSentenceOption(
    category: category,
    thaiText: thaiText,
    sentenceId: sentenceId,
  );
  return sentence?.audioPath ?? fallbackAudioPath;
}

ThaiSentenceContent? _findSentenceOption({
  required String category,
  required String thaiText,
  required String sentenceId,
}) {
  final sentences = sentencesByCategory(category);
  if (sentenceId.trim().isNotEmpty) {
    for (final sentence in sentences) {
      if (sentence.id == sentenceId) {
        return sentence;
      }
    }
  }
  final normalizedThai = thaiText.trim();
  for (final sentence in sentences) {
    if (sentence.thaiText.trim() == normalizedThai) {
      return sentence;
    }
  }
  return null;
}
