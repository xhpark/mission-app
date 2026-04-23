// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mission Language Learning';

  @override
  String get learningSelectTitle => 'Learning Selection';

  @override
  String get learningSelectSubtitle =>
      'Choose category, level, and study mode to begin.';

  @override
  String get startSession => 'Start Session';

  @override
  String get resumeSession => 'Resume Session';

  @override
  String get clearSession => 'Clear Session';

  @override
  String get failedToStartSession => 'Failed to start session.';

  @override
  String get dismissError => 'Dismiss Error';

  @override
  String get menuGuide => 'Learning Guide';

  @override
  String get menuResume => 'Resume Session';

  @override
  String get menuSignOut => 'Sign Out';

  @override
  String get categoryLabel => 'Category';

  @override
  String get levelLabel => 'Level';

  @override
  String get modeLabel => 'Mode';

  @override
  String get guideTitle => 'Learning Guide';

  @override
  String get guideHeroTitle => 'Before you begin';

  @override
  String get guideHeroSubtitle =>
      'Follow these steps to keep your session focused and consistent.';

  @override
  String get guideStart => 'Start Learning';

  @override
  String get resumeTitle => 'Resume Session';

  @override
  String get resumeHeader => 'Saved Progress Found';

  @override
  String get resumeStartNew => 'Start New Session';

  @override
  String get resumeGoToMode => 'Go to Mode';

  @override
  String get debugPanelTitle => 'QA Debug';

  @override
  String get debugRoute => 'Route';

  @override
  String get debugUserStatus => 'User Status';

  @override
  String get debugSessionId => 'Session ID';

  @override
  String get debugContentSetId => 'Content Set ID';

  @override
  String get interactiveActionError =>
      'An error occurred while processing. Please try again.';

  @override
  String get interactiveBackTooltip => 'Back';

  @override
  String get interactiveProgressTitle => 'Progress';

  @override
  String get interactiveProgressDescription =>
      'Check your current step and remaining time.';

  @override
  String interactiveRemainingSeconds(int seconds) {
    return '${seconds}s left';
  }

  @override
  String get interactivePromptDescription =>
      'Review the sentence and hint, then practice listening and speaking.';

  @override
  String get interactiveNativeAudioPause => 'Pause native audio';

  @override
  String get interactiveNativeAudioPlay => 'Play native audio';

  @override
  String get interactiveRecordStop => 'Stop recording';

  @override
  String get interactiveRecordStart => 'Start speaking practice';

  @override
  String get interactiveMyRecordingListen => 'Listen to my recording';

  @override
  String get interactiveRecordingGuidanceActive =>
      'Recording in progress. Speak clearly and slowly.';

  @override
  String get interactiveRecordingGuidanceIdle =>
      'Press the button to start recording.';

  @override
  String interactiveSimilarityScore(int score) {
    return 'Similarity score: $score';
  }

  @override
  String interactiveRecognizedText(String text) {
    return 'Recognized: $text';
  }

  @override
  String get interactiveCorrectFeedback => 'Great. That\'s correct.';

  @override
  String get interactiveIncorrectFeedback =>
      'Not quite. Review the hint and try again.';

  @override
  String get interactiveSecondaryToSelect => 'Back to selection';

  @override
  String get interactiveBlockedTimeExpired =>
      'Time is up. Go back and restart.';

  @override
  String get interactiveBlockedSelectCorrect =>
      'Select the correct answer to continue.';

  @override
  String get interactiveBlockedNeedRecording =>
      'You need at least one recording to continue.';

  @override
  String get interactiveBlockedNeedSpeakingPass =>
      'You need to pass speaking validation to continue.';

  @override
  String get interactiveNativeAudioPlayFailed => 'Failed to play native audio.';

  @override
  String get interactiveMyRecordingPlayFailed =>
      'Failed to play your recording.';

  @override
  String get interactiveStartRecordingFailed =>
      'Could not start microphone. Check permission.';

  @override
  String get interactiveRecordingStatusActive => 'Recording in progress.';

  @override
  String get interactiveSpeakingPassed => 'Speaking validation passed.';

  @override
  String get interactiveSpeakingFailed => 'Speaking validation did not pass.';

  @override
  String get interactiveRecordingProcessFailed =>
      'Recording processing failed.';

  @override
  String get sentenceLearningTitle => 'Sentence Learning';

  @override
  String get sentenceLearningNoSessionMessage =>
      'No active session. Start one from Learning Selection.';

  @override
  String get sentenceLearningGoToSelect => 'Go to Learning Selection';

  @override
  String get sentenceLearningHeroSubtitle =>
      'Practice sentence listening, speaking, and key vocabulary together.';

  @override
  String get sentenceLearningSectionTitle => 'Learning Sentence';

  @override
  String get sentenceLearningSectionDescription =>
      'Study this sentence together with related key words.';

  @override
  String sentenceLearningLoadError(String error) {
    return 'Could not load sentence. $error';
  }

  @override
  String get sentenceLearningAudioNotReady =>
      'Sentence audio is not ready yet.';

  @override
  String get sentenceLearningAudioFailed => 'Failed to play audio.';

  @override
  String get sentenceLearningListenSentence => 'Listen to sentence';

  @override
  String get sentenceLearningReadWithMyVoice => 'Read with my voice';

  @override
  String get sentenceLearningKeyWordsTitle => 'Key Words';

  @override
  String get sentenceLearningGoToSummary => 'Go to Session Summary';

  @override
  String get sentenceLearningMicPermissionError =>
      'Please check microphone permission.';

  @override
  String get sentenceLearningRecordingProcessError =>
      'An error occurred while processing recording.';

  @override
  String get sentenceLearningLoading => 'Loading sentence...';

  @override
  String get sessionSummaryTitle => 'Session Summary';

  @override
  String get sessionSummaryStatTotalItems => 'Total Items';

  @override
  String get sessionSummaryStatCompletedItems => 'Completed Items';

  @override
  String get sessionSummaryStatAccuracy => 'Accuracy';

  @override
  String get sessionSummaryStatCorrectAnswers => 'Correct Answers';

  @override
  String get sessionSummaryStatSessionId => 'Session ID';

  @override
  String get sessionSummarySubtitleNoSession =>
      'The session is complete. Review your results and submit your report.';

  @override
  String sessionSummarySubtitleWithMode(String mode) {
    return 'The $mode session is complete. Submit your report to unlock the next session.';
  }

  @override
  String get sessionSummaryHeroTitle =>
      'Great work finishing today\'s learning.';

  @override
  String get sessionSummaryResultTitle => 'Learning Result';

  @override
  String get sessionSummaryResultDescription => 'Summary of this session.';

  @override
  String get sessionSummaryCoachNote =>
      'Coach note: Your mission sentence pronunciation improved. Keep practicing speaking in the next session too.';

  @override
  String get sessionSummaryNextRecommendationTitle => 'Next Recommendation';

  @override
  String get sessionSummaryNextRecommendationDescription =>
      'Maintain momentum with short repetition practice.';

  @override
  String get sessionSummaryNextRecommendationBody =>
      'After submitting your report, the next study session will open. Advanced content is released after admin review.';

  @override
  String get sessionSummarySecondaryToSelect => 'Back to selection';

  @override
  String get sessionSummaryPrimaryToReportPreview => 'Go to Report Preview';

  @override
  String loginFailedWithError(String error) {
    return 'Login failed: $error';
  }

  @override
  String get loginContinueForDevelopment => 'Continue for Development';

  @override
  String get loginReleaseNote =>
      'Phone authentication will be enabled in release.';

  @override
  String get studyModeBackToSelection => 'Back to Selection';

  @override
  String get reportPreviewTitle => 'Report Preview';

  @override
  String get reportPreviewSessionInfoTitle => 'Session Info';

  @override
  String reportPreviewSessionId(String sessionId) {
    return 'Session ID: $sessionId';
  }

  @override
  String reportPreviewContentSet(String contentSetId) {
    return 'Content Set: $contentSetId';
  }

  @override
  String reportPreviewLearningMode(String mode) {
    return 'Learning Mode: $mode';
  }

  @override
  String reportPreviewSummary(String summary) {
    return 'Summary: $summary';
  }

  @override
  String get reportPreviewChecklistTitle => 'Before Submit';

  @override
  String get reportPreviewChecklistBody =>
      '1) Summarize today\'s learning in 1-2 sentences.\n2) Check listening and speaking practice completion.\n3) After submit, you can start the next session.';

  @override
  String get reportPreviewSecondaryToSummary => 'Back to Summary';

  @override
  String get reportPreviewPrimaryToReport => 'Write Report';

  @override
  String get reportGateTitle => 'Report Gate';

  @override
  String get reportGateRefreshTooltip => 'Refresh Status';

  @override
  String get reportGateBlockedMessage =>
      'Learning is blocked until this week\'s report is submitted.';

  @override
  String get reportGateOpenMessage =>
      'No report requirement now. You can continue learning.';

  @override
  String get reportGateStatusTitle => 'Gate Status';

  @override
  String reportGateCurrentStage(String stage) {
    return 'Current gate stage: $stage';
  }

  @override
  String get reportGateNextStepsTitle => 'Next Steps';

  @override
  String get reportGateNextStepsBody =>
      '1) Review session summary.\n2) Write your reflection.\n3) Submit report and wait for admin review.';

  @override
  String get reportGatePrimaryToPreview => 'Go to Report Preview';

  @override
  String get reportGatePrimaryToSelect => 'Go to Selection';

  @override
  String get reportTitle => 'Learning Report';

  @override
  String get reportNoSessionBanner =>
      'No active session. Report submission is unavailable.';

  @override
  String get reportAuthRequiredBanner =>
      'Report submission requires an authenticated account.';

  @override
  String get reportChecklistTitle => 'Session Checklist';

  @override
  String get reportChecklistListening => 'I completed listening practice.';

  @override
  String get reportChecklistSpeaking => 'I completed speaking practice.';

  @override
  String get reportReflectionTitle => 'Learning Reflection';

  @override
  String get reportReflectionHint => 'Write your reflection in 1-2 sentences.';

  @override
  String get reportSubmittedMessage =>
      'Report submitted. You can start the next learning.';

  @override
  String get reportSecondaryToSummary => 'Back to Summary';

  @override
  String get reportPrimaryDone => 'Submitted';

  @override
  String get reportPrimarySubmit => 'Submit Report';

  @override
  String get reportSubmitFailed =>
      'Report submission failed. Please try again.';

  @override
  String get flashSentenceLearningTitle => 'Flash Sentence Learning';

  @override
  String get flashSentenceLearningSubtitle =>
      'Build sentence fluency through short repeated cycles.';

  @override
  String flashSentenceLearningProgressLabel(int current, int total) {
    return 'Sentence $current / $total';
  }

  @override
  String get flashSentenceLearningPromptTitle => 'Today\'s Sentence';

  @override
  String get flashSentenceLearningPrimaryButton => 'Go to Flash Sentence Test';

  @override
  String get flashWordLearningTitle => 'Flash Word Learning';

  @override
  String get flashWordLearningSubtitle =>
      'Build core vocabulary through short repeated cycles.';

  @override
  String flashWordLearningProgressLabel(int current, int total) {
    return 'Word $current / $total';
  }

  @override
  String get flashWordLearningPromptTitle => 'Today\'s Word';

  @override
  String get flashWordLearningPrimaryButton => 'Go to Flash Word Test';

  @override
  String get sentenceTestChoiceTitle => 'Sentence Test - Choice';

  @override
  String get sentenceTestChoiceSubtitle =>
      'Select the Thai sentence that matches Korean.';

  @override
  String sentenceTestChoiceProgressLabel(int current, int total) {
    return 'Question $current / $total';
  }

  @override
  String get sentenceTestChoicePromptTitle => 'Choose from Korean prompt';

  @override
  String get sentenceTestChoicePrimaryButton => 'Go to Speaking Test';

  @override
  String get flashSentenceTestChoiceTitle => 'Flash Sentence Test - Choice';

  @override
  String get flashSentenceTestChoiceSubtitle =>
      'Select the Thai sentence that matches Korean.';

  @override
  String flashSentenceTestChoiceProgressLabel(int current, int total) {
    return 'Question $current / $total';
  }

  @override
  String get flashSentenceTestChoicePromptTitle => 'Translate Korean to Thai';

  @override
  String get flashSentenceTestChoicePrimaryButton => 'Go to Speaking Test';

  @override
  String get flashWordTestTitle => 'Flash Word Test';

  @override
  String get flashWordTestSubtitle => 'Select the meaning of the Thai word.';

  @override
  String flashWordTestProgressLabel(int current, int total) {
    return 'Question $current / $total';
  }

  @override
  String get flashWordTestPromptTitle => 'Check Word Meaning';

  @override
  String get flashWordTestPrimaryButton => 'Finish Test';

  @override
  String get sentenceTestSpeakingTitle => 'Sentence Test - Speaking';

  @override
  String get sentenceTestSpeakingSubtitle =>
      'Speak the prompt sentence and review your similarity score.';

  @override
  String sentenceTestSpeakingProgressLabel(int current, int total) {
    return 'Speaking $current / $total';
  }

  @override
  String get sentenceTestSpeakingPromptTitle => 'Speaking Prompt';

  @override
  String get sentenceTestSpeakingPrimaryButton => 'Finish Test';

  @override
  String get flashSentenceTestSpeakingTitle => 'Flash Sentence Test - Speaking';

  @override
  String get flashSentenceTestSpeakingSubtitle =>
      'Speak quickly and review your score.';

  @override
  String flashSentenceTestSpeakingProgressLabel(int current, int total) {
    return 'Speaking $current / $total';
  }

  @override
  String get flashSentenceTestSpeakingPromptTitle => 'Speaking Prompt';

  @override
  String get flashSentenceTestSpeakingPrimaryButton => 'Done';

  @override
  String get speakingNoRecordingData => 'No recording data. Please try again.';

  @override
  String get speakingDevModePass =>
      'In development mode, this is marked as completed.';

  @override
  String get speakingSelectAsrPolicyFirst =>
      'Select ASR policy from learning selection first.';

  @override
  String get speakingServerOnlyRequiresNetwork =>
      'Server STT only mode. Connect network and try again.';

  @override
  String get speakingNetworkOrServerFailed =>
      'Could not evaluate speech due to network/server issue.';

  @override
  String speakingServerAndOnDeviceUnavailable(String reason) {
    return 'Server and on-device ASR are unavailable. $reason';
  }

  @override
  String get speakingOnDeviceSaved => 'Processed by on-device ASR.';

  @override
  String get speakingOnDeviceSaveFailed =>
      'Failed to save on-device result. Try again.';

  @override
  String get guidePrinciplesTitle => 'Learning & Report Principles';

  @override
  String get guideStepsTitle => 'Flow Steps';

  @override
  String get guidePrinciple1 =>
      'Learning content uses bundled sentence, word, and audio data first.';

  @override
  String get guidePrinciple2 =>
      'Learning history is cumulative and preserved before report submit.';

  @override
  String get guidePrinciple3 =>
      'If you choose start new, the previous active session is abandoned.';

  @override
  String get guidePrinciple4 =>
      'Report submission is learner-driven and can be done anytime in session.';

  @override
  String get guidePrinciple5 =>
      'Retry and sync paths are kept for network and error resilience.';

  @override
  String get guideStep1 => 'Choose category, level, and mode.';

  @override
  String get guideStep2 =>
      'Proceed sentence/word learning and use resume as needed.';

  @override
  String get guideStep3 => 'Complete tests and review summary.';

  @override
  String get guideStep4 => 'Submit cumulative report at your chosen timing.';

  @override
  String get learningSelectActiveSessionTitle =>
      'There is an active learning session.';

  @override
  String get learningSelectStartNewButton => 'Start New';

  @override
  String get learningSelectStarting => 'Starting session...';

  @override
  String get learningSelectConfirmStartNewTitle =>
      'Start a new learning session?';

  @override
  String get learningSelectConfirmStartNewMessage =>
      'Current session will be abandoned. If you want to continue it, cancel and tap resume.';

  @override
  String get learningSelectConfirmCancel => 'Cancel';

  @override
  String get learningSelectConfirmStartNew => 'Start New';

  @override
  String get learningSelectAsrPolicyTitle => 'Speech Recognition Policy';

  @override
  String get learningSelectAsrPolicyIntro =>
      'Choose speech recognition mode. You can change it later.';

  @override
  String get learningSelectAsrPolicyServerOnly => 'Server STT Only';

  @override
  String get learningSelectAsrPolicyOffline => 'Offline Support';

  @override
  String get learningSelectAsrPolicyServerOnlyDesc =>
      'No local model download. Offline evaluation is unavailable.';

  @override
  String get learningSelectAsrPolicyOfflineDesc =>
      'With local ASR, speaking evaluation can continue offline.';

  @override
  String get learningSelectAsrSyncNow => 'Sync Now';

  @override
  String learningSelectAsrPendingSync(int count) {
    return '$count offline results pending sync.';
  }

  @override
  String get learningSelectAsrNoPendingSync => 'No pending offline sync.';

  @override
  String get learningSelectCategoryDaily => 'Daily Conversation';

  @override
  String get learningSelectCategoryMission => 'Mission';

  @override
  String get learningSelectLevelBeginner => 'Beginner';

  @override
  String get learningSelectLevelIntermediate => 'Intermediate';

  @override
  String get learningSelectLevelAdvanced => 'Advanced';

  @override
  String get learningSelectModeSentenceLearning => 'Sentence Learning';

  @override
  String get learningSelectModeSentenceTest => 'Sentence Test';

  @override
  String get learningSelectModeFlashWordLearning => 'Flash Word Learning';

  @override
  String get learningSelectModeFlashWordTest => 'Flash Word Test';

  @override
  String get learningSelectModeFlashSentenceLearning =>
      'Flash Sentence Learning';

  @override
  String get learningSelectModeFlashSentenceTest => 'Flash Sentence Test';

  @override
  String get learningSelectUnselected => 'Not selected';

  @override
  String learningSelectSelectionSummary(
    String category,
    String level,
    String mode,
  ) {
    return 'Current selection: category $category / level $level / mode $mode';
  }

  @override
  String get learningSelectModeDescSentenceLearning =>
      'Study sentence with pronunciation and hints step by step.';

  @override
  String get learningSelectModeDescSentenceTest =>
      'Validate sentence understanding via choice and speaking.';

  @override
  String get learningSelectModeDescFlashWordLearning =>
      'Memorize core words quickly with flash repetition.';

  @override
  String get learningSelectModeDescFlashWordTest =>
      'Check word memory quickly with short tests.';

  @override
  String get learningSelectModeDescFlashSentenceLearning =>
      'Practice sentences with high-tempo flash cards.';

  @override
  String get learningSelectModeDescFlashSentenceTest =>
      'Validate sentence comprehension and speaking in quick cycles.';

  @override
  String get learningSelectModeDescNone => 'Select a mode to see guidance.';

  @override
  String get sentenceLearningPlaceholder =>
      'Preparing sentence learning content.';

  @override
  String get sentenceLearningPronunciationLabel => 'Pronunciation';

  @override
  String get sentenceLearningHintLabel => 'Hint';

  @override
  String sentenceLearningProgress(int current, int total) {
    return 'Progress: $current / $total';
  }

  @override
  String get sentenceLearningSessionCompletedMessage =>
      'Sentence learning session is complete.';

  @override
  String get sentenceLearningCompleteAndContinue => 'Complete and Continue';

  @override
  String get adminContactLabel => 'Admin Contact';

  @override
  String get loginTitle => 'Learner Login';

  @override
  String get loginSubtitle =>
      'Use development mode login until phone auth is enabled.';

  @override
  String get approvalPendingTitle => 'Approval Pending';

  @override
  String get approvalPendingMessage =>
      'Login is complete. Admin approval is required before learning starts.';

  @override
  String get refreshStatus => 'Refresh Status';

  @override
  String get backToLogin => 'Back to Login';

  @override
  String get blockedTitle => 'Access Restricted';

  @override
  String get blockedMessage =>
      'This account is currently restricted. Please contact admin.';

  @override
  String get bootstrapMessage => 'Checking your learning status...';

  @override
  String get learningBlockedTitle => 'Learning Temporarily Blocked';

  @override
  String get learningBlockedMessage =>
      'Learning is paused until mandatory report is submitted.';
}
