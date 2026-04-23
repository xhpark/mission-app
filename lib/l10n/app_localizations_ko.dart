// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '미션 언어 학습';

  @override
  String get learningSelectTitle => '학습 선택';

  @override
  String get learningSelectSubtitle => '카테고리, 난이도, 학습 모드를 선택하고 시작하세요.';

  @override
  String get startSession => '학습 시작';

  @override
  String get resumeSession => '이어서 학습';

  @override
  String get clearSession => '세션 초기화';

  @override
  String get failedToStartSession => '학습 세션 시작에 실패했습니다.';

  @override
  String get dismissError => '오류 닫기';

  @override
  String get menuGuide => '학습 가이드';

  @override
  String get menuResume => '이어하기';

  @override
  String get menuSignOut => '로그아웃';

  @override
  String get categoryLabel => '카테고리';

  @override
  String get levelLabel => '난이도';

  @override
  String get modeLabel => '학습 모드';

  @override
  String get guideTitle => '학습 가이드';

  @override
  String get guideHeroTitle => '시작 전에 확인하세요';

  @override
  String get guideHeroSubtitle => '아래 순서대로 진행하면 학습 흐름을 안정적으로 유지할 수 있습니다.';

  @override
  String get guideStart => '학습 시작하기';

  @override
  String get resumeTitle => '학습 이어하기';

  @override
  String get resumeHeader => '저장된 진행 정보';

  @override
  String get resumeStartNew => '새 세션 시작';

  @override
  String get resumeGoToMode => '선택 화면으로 이동';

  @override
  String get debugPanelTitle => 'QA 디버그';

  @override
  String get debugRoute => '현재 경로';

  @override
  String get debugUserStatus => '사용자 상태';

  @override
  String get debugSessionId => '세션 ID';

  @override
  String get debugContentSetId => '콘텐츠 세트 ID';

  @override
  String get interactiveActionError => '처리 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get interactiveBackTooltip => '뒤로가기';

  @override
  String get interactiveProgressTitle => '진행 상태';

  @override
  String get interactiveProgressDescription => '현재 단계와 남은 시간을 확인하세요.';

  @override
  String interactiveRemainingSeconds(int seconds) {
    return '남은 시간 $seconds초';
  }

  @override
  String get interactivePromptDescription => '문장과 힌트를 확인하고, 듣기/말하기를 진행하세요.';

  @override
  String get interactiveNativeAudioPause => '원어민 음성 일시정지';

  @override
  String get interactiveNativeAudioPlay => '원어민 음성 재생';

  @override
  String get interactiveRecordStop => '녹음 중지';

  @override
  String get interactiveRecordStart => '말하기 연습 시작';

  @override
  String get interactiveMyRecordingListen => '내 녹음 듣기';

  @override
  String get interactiveRecordingGuidanceActive => '녹음 중입니다. 천천히 또렷하게 말해 주세요.';

  @override
  String get interactiveRecordingGuidanceIdle => '버튼을 눌러 녹음을 시작해 주세요.';

  @override
  String interactiveSimilarityScore(int score) {
    return '유사도 점수: $score점';
  }

  @override
  String interactiveRecognizedText(String text) {
    return '인식 문장: $text';
  }

  @override
  String get interactiveCorrectFeedback => '좋아요. 정답입니다.';

  @override
  String get interactiveIncorrectFeedback => '아쉽습니다. 힌트를 다시 보고 재도전해 보세요.';

  @override
  String get interactiveSecondaryToSelect => '선택 화면으로';

  @override
  String get interactiveBlockedTimeExpired =>
      '제한 시간이 종료되었습니다. 뒤로가기 후 다시 시작해 주세요.';

  @override
  String get interactiveBlockedSelectCorrect => '정답을 선택해야 다음으로 진행할 수 있습니다.';

  @override
  String get interactiveBlockedNeedRecording => '최소 1회 녹음을 완료해야 진행할 수 있습니다.';

  @override
  String get interactiveBlockedNeedSpeakingPass => '발음 평가 점수를 통과해야 진행할 수 있습니다.';

  @override
  String get interactiveNativeAudioPlayFailed => '원어민 음성을 재생하지 못했습니다.';

  @override
  String get interactiveMyRecordingPlayFailed => '내 녹음을 재생하지 못했습니다.';

  @override
  String get interactiveStartRecordingFailed => '마이크를 시작하지 못했습니다. 권한을 확인해 주세요.';

  @override
  String get interactiveRecordingStatusActive => '녹음 중입니다.';

  @override
  String get interactiveSpeakingPassed => '발음 평가를 통과했습니다.';

  @override
  String get interactiveSpeakingFailed => '발음 평가를 통과하지 못했습니다.';

  @override
  String get interactiveRecordingProcessFailed => '녹음 처리 중 오류가 발생했습니다.';

  @override
  String get sentenceLearningTitle => '문장 학습';

  @override
  String get sentenceLearningNoSessionMessage =>
      '진행 중인 세션이 없습니다. 학습 선택 화면에서 세션을 시작해 주세요.';

  @override
  String get sentenceLearningGoToSelect => '학습 선택으로 이동';

  @override
  String get sentenceLearningHeroSubtitle => '문장 듣기, 말하기, 주요 단어 학습을 함께 진행합니다.';

  @override
  String get sentenceLearningSectionTitle => '학습 문장';

  @override
  String get sentenceLearningSectionDescription => '문장과 관련 주요 단어를 함께 학습하세요.';

  @override
  String sentenceLearningLoadError(String error) {
    return '문장을 불러오지 못했습니다. $error';
  }

  @override
  String get sentenceLearningAudioNotReady => '듣기 음성이 아직 준비되지 않았습니다.';

  @override
  String get sentenceLearningAudioFailed => '음성 재생에 실패했습니다.';

  @override
  String get sentenceLearningListenSentence => '문장 들어보기';

  @override
  String get sentenceLearningReadWithMyVoice => '내 목소리로 읽기';

  @override
  String get sentenceLearningKeyWordsTitle => '주요 단어';

  @override
  String get sentenceLearningGoToSummary => '세션 요약으로 이동';

  @override
  String get sentenceLearningMicPermissionError => '마이크 권한을 확인해 주세요.';

  @override
  String get sentenceLearningRecordingProcessError => '녹음 처리 중 오류가 발생했습니다.';

  @override
  String get sentenceLearningLoading => '문장을 불러오는 중입니다...';

  @override
  String get sessionSummaryTitle => '세션 요약';

  @override
  String get sessionSummaryStatTotalItems => '총 학습 항목';

  @override
  String get sessionSummaryStatCompletedItems => '완료 항목';

  @override
  String get sessionSummaryStatAccuracy => '정확도';

  @override
  String get sessionSummaryStatCorrectAnswers => '정답 수';

  @override
  String get sessionSummaryStatSessionId => '세션 ID';

  @override
  String get sessionSummarySubtitleNoSession =>
      '학습 세션이 완료되었습니다. 결과를 확인한 뒤 리포트를 제출하세요.';

  @override
  String sessionSummarySubtitleWithMode(String mode) {
    return '$mode 세션이 완료되었습니다. 리포트를 제출하면 다음 세션이 열립니다.';
  }

  @override
  String get sessionSummaryHeroTitle => '오늘 학습을 잘 마쳤어요.';

  @override
  String get sessionSummaryResultTitle => '학습 결과';

  @override
  String get sessionSummaryResultDescription => '오늘 세션에서 진행한 요약입니다.';

  @override
  String get sessionSummaryCoachNote =>
      '코치 노트: 미션 문장의 발음이 개선되었습니다. 다음 세션에서도 말하기 연습을 이어가세요.';

  @override
  String get sessionSummaryNextRecommendationTitle => '다음 추천';

  @override
  String get sessionSummaryNextRecommendationDescription =>
      '짧은 반복 학습으로 성취감을 유지해 보세요.';

  @override
  String get sessionSummaryNextRecommendationBody =>
      '리포트를 제출하면 다음 학습 세션이 열리고, 관리자 확인 이후 고급 콘텐츠가 순차적으로 제공됩니다.';

  @override
  String get sessionSummarySecondaryToSelect => '선택 화면으로';

  @override
  String get sessionSummaryPrimaryToReportPreview => '리포트 프리뷰로';

  @override
  String loginFailedWithError(String error) {
    return '로그인에 실패했습니다: $error';
  }

  @override
  String get loginContinueForDevelopment => '개발용으로 계속하기';

  @override
  String get loginReleaseNote => '정식 배포에서는 휴대전화 인증이 활성화됩니다.';

  @override
  String get studyModeBackToSelection => '학습 선택으로 돌아가기';

  @override
  String get reportPreviewTitle => '리포트 프리뷰';

  @override
  String get reportPreviewSessionInfoTitle => '세션 정보';

  @override
  String reportPreviewSessionId(String sessionId) {
    return '세션 ID: $sessionId';
  }

  @override
  String reportPreviewContentSet(String contentSetId) {
    return '콘텐츠 세트: $contentSetId';
  }

  @override
  String reportPreviewLearningMode(String mode) {
    return '학습 모드: $mode';
  }

  @override
  String reportPreviewSummary(String summary) {
    return '요약: $summary';
  }

  @override
  String get reportPreviewChecklistTitle => '제출 전 확인';

  @override
  String get reportPreviewChecklistBody =>
      '1) 오늘 학습 내용을 1~2문장으로 정리합니다.\n2) 듣기/말하기 완료 여부를 확인합니다.\n3) 제출 후 다음 세션을 시작할 수 있습니다.';

  @override
  String get reportPreviewSecondaryToSummary => '요약으로 돌아가기';

  @override
  String get reportPreviewPrimaryToReport => '리포트 작성';

  @override
  String get reportGateTitle => '리포트 게이트';

  @override
  String get reportGateRefreshTooltip => '상태 새로고침';

  @override
  String get reportGateBlockedMessage => '이번 주 리포트를 제출하기 전까지 학습이 차단됩니다.';

  @override
  String get reportGateOpenMessage => '현재는 리포트 제출 의무가 없습니다. 계속 학습할 수 있습니다.';

  @override
  String get reportGateStatusTitle => '게이트 상태';

  @override
  String reportGateCurrentStage(String stage) {
    return '현재 게이트 단계: $stage';
  }

  @override
  String get reportGateNextStepsTitle => '다음 단계';

  @override
  String get reportGateNextStepsBody =>
      '1) 세션 요약을 확인합니다.\n2) 학습 소감을 작성합니다.\n3) 리포트를 제출하고 관리자 검토를 기다립니다.';

  @override
  String get reportGatePrimaryToPreview => '리포트 프리뷰로 이동';

  @override
  String get reportGatePrimaryToSelect => '학습 선택으로 이동';

  @override
  String get reportTitle => '학습 리포트';

  @override
  String get reportNoSessionBanner => '활성 세션이 없습니다. 리포트 제출을 진행할 수 없습니다.';

  @override
  String get reportAuthRequiredBanner => '리포트 제출은 인증된 계정에서만 가능합니다.';

  @override
  String get reportChecklistTitle => '세션 체크리스트';

  @override
  String get reportChecklistListening => '듣기 학습을 완료했습니다.';

  @override
  String get reportChecklistSpeaking => '말하기 학습을 완료했습니다.';

  @override
  String get reportReflectionTitle => '학습 소감';

  @override
  String get reportReflectionHint => '학습 소감을 1~2문장으로 작성해 주세요.';

  @override
  String get reportSubmittedMessage => '리포트를 제출했습니다. 다음 학습을 시작할 수 있습니다.';

  @override
  String get reportSecondaryToSummary => '요약으로 돌아가기';

  @override
  String get reportPrimaryDone => '제출 완료';

  @override
  String get reportPrimarySubmit => '리포트 제출';

  @override
  String get reportSubmitFailed => '리포트 제출에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get flashSentenceLearningTitle => '플래시 문장 학습';

  @override
  String get flashSentenceLearningSubtitle => '짧고 반복적인 흐름으로 문장 감각을 익혀요.';

  @override
  String flashSentenceLearningProgressLabel(int current, int total) {
    return '문장 $current / $total';
  }

  @override
  String get flashSentenceLearningPromptTitle => '오늘의 문장';

  @override
  String get flashSentenceLearningPrimaryButton => '플래시 문장 테스트로 이동';

  @override
  String get flashWordLearningTitle => '플래시 단어 학습';

  @override
  String get flashWordLearningSubtitle => '짧은 반복으로 핵심 단어를 빠르게 익혀요.';

  @override
  String flashWordLearningProgressLabel(int current, int total) {
    return '단어 $current / $total';
  }

  @override
  String get flashWordLearningPromptTitle => '오늘의 단어';

  @override
  String get flashWordLearningPrimaryButton => '플래시 단어 테스트로 이동';

  @override
  String get sentenceTestChoiceTitle => '문장 테스트 - 선택형';

  @override
  String get sentenceTestChoiceSubtitle => '한국어 문장에 맞는 태국어 문장을 선택하세요.';

  @override
  String sentenceTestChoiceProgressLabel(int current, int total) {
    return '문항 $current / $total';
  }

  @override
  String get sentenceTestChoicePromptTitle => '한국어 제시문 보고 선택';

  @override
  String get sentenceTestChoicePrimaryButton => '말하기 테스트로 이동';

  @override
  String get flashSentenceTestChoiceTitle => '플래시 문장 테스트 - 선택형';

  @override
  String get flashSentenceTestChoiceSubtitle => '한국어 문장에 맞는 태국어를 선택하세요.';

  @override
  String flashSentenceTestChoiceProgressLabel(int current, int total) {
    return '문항 $current / $total';
  }

  @override
  String get flashSentenceTestChoicePromptTitle => '한국어를 태국어로 고르기';

  @override
  String get flashSentenceTestChoicePrimaryButton => '말하기 테스트로 이동';

  @override
  String get flashWordTestTitle => '플래시 단어 테스트';

  @override
  String get flashWordTestSubtitle => '태국어 단어의 의미를 선택하세요.';

  @override
  String flashWordTestProgressLabel(int current, int total) {
    return '문항 $current / $total';
  }

  @override
  String get flashWordTestPromptTitle => '단어 의미 확인';

  @override
  String get flashWordTestPrimaryButton => '테스트 종료';

  @override
  String get sentenceTestSpeakingTitle => '문장 테스트 - 말하기';

  @override
  String get sentenceTestSpeakingSubtitle => '제시 문장을 말하고 유사도 점수를 확인하세요.';

  @override
  String sentenceTestSpeakingProgressLabel(int current, int total) {
    return '말하기 $current / $total';
  }

  @override
  String get sentenceTestSpeakingPromptTitle => '말하기 제시문';

  @override
  String get sentenceTestSpeakingPrimaryButton => '테스트 종료';

  @override
  String get flashSentenceTestSpeakingTitle => '플래시 문장 테스트 - 말하기';

  @override
  String get flashSentenceTestSpeakingSubtitle => '빠르게 말하고 유사도 점수를 확인해요.';

  @override
  String flashSentenceTestSpeakingProgressLabel(int current, int total) {
    return '말하기 $current / $total';
  }

  @override
  String get flashSentenceTestSpeakingPromptTitle => '말하기 제시문';

  @override
  String get flashSentenceTestSpeakingPrimaryButton => '완료';

  @override
  String get speakingNoRecordingData => '녹음 데이터가 없습니다. 다시 시도해 주세요.';

  @override
  String get speakingDevModePass => '개발 모드에서는 완료 처리됩니다.';

  @override
  String get speakingSelectAsrPolicyFirst => '학습 선택 화면에서 ASR 정책을 먼저 선택해 주세요.';

  @override
  String get speakingServerOnlyRequiresNetwork =>
      '서버 STT 전용 모드입니다. 네트워크 연결 후 다시 시도해 주세요.';

  @override
  String get speakingNetworkOrServerFailed => '네트워크/서버 문제로 말하기 평가를 진행하지 못했습니다.';

  @override
  String speakingServerAndOnDeviceUnavailable(String reason) {
    return '서버와 온디바이스 ASR을 모두 사용할 수 없습니다. $reason';
  }

  @override
  String get speakingOnDeviceSaved => '온디바이스 ASR로 처리되었습니다.';

  @override
  String get speakingOnDeviceSaveFailed => '온디바이스 결과 저장에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get guidePrinciplesTitle => '학습/리포트 운영 원칙';

  @override
  String get guideStepsTitle => '학습 흐름';

  @override
  String get guidePrinciple1 => '학습 콘텐츠는 앱 내 포함된 문장/단어/오디오 데이터를 우선 사용합니다.';

  @override
  String get guidePrinciple2 => '학습 이력은 누적되며 리포트 제출 전까지 유지됩니다.';

  @override
  String get guidePrinciple3 => '새 학습 시작을 선택하면 이전 활성 세션은 포기 처리됩니다.';

  @override
  String get guidePrinciple4 => '리포트 제출은 학습자 주도로 세션 내 원하는 시점에 가능합니다.';

  @override
  String get guidePrinciple5 => '네트워크 장애를 대비해 재시도/동기화 경로를 제공합니다.';

  @override
  String get guideStep1 => '카테고리, 레벨, 학습 모드를 선택합니다.';

  @override
  String get guideStep2 => '문장/단어 학습을 진행하고 필요 시 이어하기를 사용합니다.';

  @override
  String get guideStep3 => '테스트를 완료하고 요약을 확인합니다.';

  @override
  String get guideStep4 => '원하는 시점에 누적 리포트를 제출합니다.';

  @override
  String get learningSelectActiveSessionTitle => '진행 중인 학습 세션이 있습니다.';

  @override
  String get learningSelectStartNewButton => '새 학습 시작';

  @override
  String get learningSelectStarting => '세션을 시작하는 중...';

  @override
  String get learningSelectConfirmStartNewTitle => '새 학습 세션을 시작할까요?';

  @override
  String get learningSelectConfirmStartNewMessage =>
      '현재 세션은 포기 처리됩니다. 이어서 학습하려면 취소 후 이어하기를 누르세요.';

  @override
  String get learningSelectConfirmCancel => '취소';

  @override
  String get learningSelectConfirmStartNew => '새로 시작';

  @override
  String get learningSelectAsrPolicyTitle => '음성 인식 정책';

  @override
  String get learningSelectAsrPolicyIntro =>
      '음성 인식 정책을 선택하세요. 이후에도 변경할 수 있습니다.';

  @override
  String get learningSelectAsrPolicyServerOnly => '서버 STT 전용';

  @override
  String get learningSelectAsrPolicyOffline => '오프라인 지원';

  @override
  String get learningSelectAsrPolicyServerOnlyDesc =>
      '로컬 모델 다운로드 없이 사용합니다. 오프라인 평가는 불가합니다.';

  @override
  String get learningSelectAsrPolicyOfflineDesc =>
      '로컬 ASR 사용 시 오프라인에서도 말하기 평가를 계속할 수 있습니다.';

  @override
  String get learningSelectAsrSyncNow => '지금 동기화';

  @override
  String learningSelectAsrPendingSync(int count) {
    return '오프라인 결과 $count건이 동기화 대기 중입니다.';
  }

  @override
  String get learningSelectAsrNoPendingSync => '오프라인 동기화 대기 항목이 없습니다.';

  @override
  String get learningSelectCategoryDaily => '일상 회화';

  @override
  String get learningSelectCategoryMission => '선교';

  @override
  String get learningSelectLevelBeginner => '초급';

  @override
  String get learningSelectLevelIntermediate => '중급';

  @override
  String get learningSelectLevelAdvanced => '고급';

  @override
  String get learningSelectModeSentenceLearning => '문장 학습';

  @override
  String get learningSelectModeSentenceTest => '문장 테스트';

  @override
  String get learningSelectModeFlashWordLearning => '플래시 단어 학습';

  @override
  String get learningSelectModeFlashWordTest => '플래시 단어 테스트';

  @override
  String get learningSelectModeFlashSentenceLearning => '플래시 문장 학습';

  @override
  String get learningSelectModeFlashSentenceTest => '플래시 문장 테스트';

  @override
  String get learningSelectUnselected => '미선택';

  @override
  String learningSelectSelectionSummary(
    String category,
    String level,
    String mode,
  ) {
    return '현재 선택: 카테고리 $category / 레벨 $level / 모드 $mode';
  }

  @override
  String get learningSelectModeDescSentenceLearning =>
      '발음/힌트와 함께 문장을 단계적으로 학습합니다.';

  @override
  String get learningSelectModeDescSentenceTest => '선택형과 말하기로 문장 이해를 검증합니다.';

  @override
  String get learningSelectModeDescFlashWordLearning =>
      '플래시 반복으로 핵심 단어를 빠르게 암기합니다.';

  @override
  String get learningSelectModeDescFlashWordTest => '짧은 테스트로 단어 기억을 점검합니다.';

  @override
  String get learningSelectModeDescFlashSentenceLearning =>
      '빠른 템포의 플래시 카드로 문장을 반복 연습합니다.';

  @override
  String get learningSelectModeDescFlashSentenceTest =>
      '빠른 사이클로 문장 이해와 말하기를 점검합니다.';

  @override
  String get learningSelectModeDescNone => '모드를 선택하면 안내가 표시됩니다.';

  @override
  String get sentenceLearningPlaceholder => '문장 학습 콘텐츠를 준비하고 있습니다.';

  @override
  String get sentenceLearningPronunciationLabel => '발음';

  @override
  String get sentenceLearningHintLabel => '힌트';

  @override
  String sentenceLearningProgress(int current, int total) {
    return '진행률: $current / $total';
  }

  @override
  String get sentenceLearningSessionCompletedMessage => '문장 학습 세션을 완료했습니다.';

  @override
  String get sentenceLearningCompleteAndContinue => '완료하고 다음으로';

  @override
  String get adminContactLabel => '??? ???';

  @override
  String get loginTitle => '??? ???';

  @override
  String get loginSubtitle => '???? ?? ?? ??? ?? ?? ????? ?????.';

  @override
  String get approvalPendingTitle => '?? ??';

  @override
  String get approvalPendingMessage => '???? ???????. ?? ?? ? ??? ??? ?????.';

  @override
  String get refreshStatus => '?? ????';

  @override
  String get backToLogin => '????? ????';

  @override
  String get blockedTitle => '?? ??';

  @override
  String get blockedMessage => '?? ??? ?? ?????. ????? ??? ???.';

  @override
  String get bootstrapMessage => '?? ??? ???? ????...';

  @override
  String get learningBlockedTitle => '?? ?? ??';

  @override
  String get learningBlockedMessage => '?? ???? ??? ??? ??? ?? ?????.';
}
