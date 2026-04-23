import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Mission Language Learning'**
  String get appTitle;

  /// No description provided for @learningSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Selection'**
  String get learningSelectTitle;

  /// No description provided for @learningSelectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose category, level, and study mode to begin.'**
  String get learningSelectSubtitle;

  /// No description provided for @startSession.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get startSession;

  /// No description provided for @resumeSession.
  ///
  /// In en, this message translates to:
  /// **'Resume Session'**
  String get resumeSession;

  /// No description provided for @clearSession.
  ///
  /// In en, this message translates to:
  /// **'Clear Session'**
  String get clearSession;

  /// No description provided for @failedToStartSession.
  ///
  /// In en, this message translates to:
  /// **'Failed to start session.'**
  String get failedToStartSession;

  /// No description provided for @dismissError.
  ///
  /// In en, this message translates to:
  /// **'Dismiss Error'**
  String get dismissError;

  /// No description provided for @menuGuide.
  ///
  /// In en, this message translates to:
  /// **'Learning Guide'**
  String get menuGuide;

  /// No description provided for @menuResume.
  ///
  /// In en, this message translates to:
  /// **'Resume Session'**
  String get menuResume;

  /// No description provided for @menuSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get menuSignOut;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get levelLabel;

  /// No description provided for @modeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get modeLabel;

  /// No description provided for @guideTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Guide'**
  String get guideTitle;

  /// No description provided for @guideHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you begin'**
  String get guideHeroTitle;

  /// No description provided for @guideHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow these steps to keep your session focused and consistent.'**
  String get guideHeroSubtitle;

  /// No description provided for @guideStart.
  ///
  /// In en, this message translates to:
  /// **'Start Learning'**
  String get guideStart;

  /// No description provided for @resumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Resume Session'**
  String get resumeTitle;

  /// No description provided for @resumeHeader.
  ///
  /// In en, this message translates to:
  /// **'Saved Progress Found'**
  String get resumeHeader;

  /// No description provided for @resumeStartNew.
  ///
  /// In en, this message translates to:
  /// **'Start New Session'**
  String get resumeStartNew;

  /// No description provided for @resumeGoToMode.
  ///
  /// In en, this message translates to:
  /// **'Go to Mode'**
  String get resumeGoToMode;

  /// No description provided for @debugPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'QA Debug'**
  String get debugPanelTitle;

  /// No description provided for @debugRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get debugRoute;

  /// No description provided for @debugUserStatus.
  ///
  /// In en, this message translates to:
  /// **'User Status'**
  String get debugUserStatus;

  /// No description provided for @debugSessionId.
  ///
  /// In en, this message translates to:
  /// **'Session ID'**
  String get debugSessionId;

  /// No description provided for @debugContentSetId.
  ///
  /// In en, this message translates to:
  /// **'Content Set ID'**
  String get debugContentSetId;

  /// No description provided for @interactiveActionError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while processing. Please try again.'**
  String get interactiveActionError;

  /// No description provided for @interactiveBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get interactiveBackTooltip;

  /// No description provided for @interactiveProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get interactiveProgressTitle;

  /// No description provided for @interactiveProgressDescription.
  ///
  /// In en, this message translates to:
  /// **'Check your current step and remaining time.'**
  String get interactiveProgressDescription;

  /// No description provided for @interactiveRemainingSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s left'**
  String interactiveRemainingSeconds(int seconds);

  /// No description provided for @interactivePromptDescription.
  ///
  /// In en, this message translates to:
  /// **'Review the sentence and hint, then practice listening and speaking.'**
  String get interactivePromptDescription;

  /// No description provided for @interactiveNativeAudioPause.
  ///
  /// In en, this message translates to:
  /// **'Pause native audio'**
  String get interactiveNativeAudioPause;

  /// No description provided for @interactiveNativeAudioPlay.
  ///
  /// In en, this message translates to:
  /// **'Play native audio'**
  String get interactiveNativeAudioPlay;

  /// No description provided for @interactiveRecordStop.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get interactiveRecordStop;

  /// No description provided for @interactiveRecordStart.
  ///
  /// In en, this message translates to:
  /// **'Start speaking practice'**
  String get interactiveRecordStart;

  /// No description provided for @interactiveMyRecordingListen.
  ///
  /// In en, this message translates to:
  /// **'Listen to my recording'**
  String get interactiveMyRecordingListen;

  /// No description provided for @interactiveRecordingGuidanceActive.
  ///
  /// In en, this message translates to:
  /// **'Recording in progress. Speak clearly and slowly.'**
  String get interactiveRecordingGuidanceActive;

  /// No description provided for @interactiveRecordingGuidanceIdle.
  ///
  /// In en, this message translates to:
  /// **'Press the button to start recording.'**
  String get interactiveRecordingGuidanceIdle;

  /// No description provided for @interactiveSimilarityScore.
  ///
  /// In en, this message translates to:
  /// **'Similarity score: {score}'**
  String interactiveSimilarityScore(int score);

  /// No description provided for @interactiveRecognizedText.
  ///
  /// In en, this message translates to:
  /// **'Recognized: {text}'**
  String interactiveRecognizedText(String text);

  /// No description provided for @interactiveCorrectFeedback.
  ///
  /// In en, this message translates to:
  /// **'Great. That\'s correct.'**
  String get interactiveCorrectFeedback;

  /// No description provided for @interactiveIncorrectFeedback.
  ///
  /// In en, this message translates to:
  /// **'Not quite. Review the hint and try again.'**
  String get interactiveIncorrectFeedback;

  /// No description provided for @interactiveSecondaryToSelect.
  ///
  /// In en, this message translates to:
  /// **'Back to selection'**
  String get interactiveSecondaryToSelect;

  /// No description provided for @interactiveBlockedTimeExpired.
  ///
  /// In en, this message translates to:
  /// **'Time is up. Go back and restart.'**
  String get interactiveBlockedTimeExpired;

  /// No description provided for @interactiveBlockedSelectCorrect.
  ///
  /// In en, this message translates to:
  /// **'Select the correct answer to continue.'**
  String get interactiveBlockedSelectCorrect;

  /// No description provided for @interactiveBlockedNeedRecording.
  ///
  /// In en, this message translates to:
  /// **'You need at least one recording to continue.'**
  String get interactiveBlockedNeedRecording;

  /// No description provided for @interactiveBlockedNeedSpeakingPass.
  ///
  /// In en, this message translates to:
  /// **'You need to pass speaking validation to continue.'**
  String get interactiveBlockedNeedSpeakingPass;

  /// No description provided for @interactiveNativeAudioPlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to play native audio.'**
  String get interactiveNativeAudioPlayFailed;

  /// No description provided for @interactiveMyRecordingPlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to play your recording.'**
  String get interactiveMyRecordingPlayFailed;

  /// No description provided for @interactiveStartRecordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start microphone. Check permission.'**
  String get interactiveStartRecordingFailed;

  /// No description provided for @interactiveRecordingStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Recording in progress.'**
  String get interactiveRecordingStatusActive;

  /// No description provided for @interactiveSpeakingPassed.
  ///
  /// In en, this message translates to:
  /// **'Speaking validation passed.'**
  String get interactiveSpeakingPassed;

  /// No description provided for @interactiveSpeakingFailed.
  ///
  /// In en, this message translates to:
  /// **'Speaking validation did not pass.'**
  String get interactiveSpeakingFailed;

  /// No description provided for @interactiveRecordingProcessFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording processing failed.'**
  String get interactiveRecordingProcessFailed;

  /// No description provided for @sentenceLearningTitle.
  ///
  /// In en, this message translates to:
  /// **'Sentence Learning'**
  String get sentenceLearningTitle;

  /// No description provided for @sentenceLearningNoSessionMessage.
  ///
  /// In en, this message translates to:
  /// **'No active session. Start one from Learning Selection.'**
  String get sentenceLearningNoSessionMessage;

  /// No description provided for @sentenceLearningGoToSelect.
  ///
  /// In en, this message translates to:
  /// **'Go to Learning Selection'**
  String get sentenceLearningGoToSelect;

  /// No description provided for @sentenceLearningHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Practice sentence listening, speaking, and key vocabulary together.'**
  String get sentenceLearningHeroSubtitle;

  /// No description provided for @sentenceLearningSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Sentence'**
  String get sentenceLearningSectionTitle;

  /// No description provided for @sentenceLearningSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Study this sentence together with related key words.'**
  String get sentenceLearningSectionDescription;

  /// No description provided for @sentenceLearningLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load sentence. {error}'**
  String sentenceLearningLoadError(String error);

  /// No description provided for @sentenceLearningAudioNotReady.
  ///
  /// In en, this message translates to:
  /// **'Sentence audio is not ready yet.'**
  String get sentenceLearningAudioNotReady;

  /// No description provided for @sentenceLearningAudioFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to play audio.'**
  String get sentenceLearningAudioFailed;

  /// No description provided for @sentenceLearningListenSentence.
  ///
  /// In en, this message translates to:
  /// **'Listen to sentence'**
  String get sentenceLearningListenSentence;

  /// No description provided for @sentenceLearningReadWithMyVoice.
  ///
  /// In en, this message translates to:
  /// **'Read with my voice'**
  String get sentenceLearningReadWithMyVoice;

  /// No description provided for @sentenceLearningKeyWordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Key Words'**
  String get sentenceLearningKeyWordsTitle;

  /// No description provided for @sentenceLearningGoToSummary.
  ///
  /// In en, this message translates to:
  /// **'Go to Session Summary'**
  String get sentenceLearningGoToSummary;

  /// No description provided for @sentenceLearningMicPermissionError.
  ///
  /// In en, this message translates to:
  /// **'Please check microphone permission.'**
  String get sentenceLearningMicPermissionError;

  /// No description provided for @sentenceLearningRecordingProcessError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while processing recording.'**
  String get sentenceLearningRecordingProcessError;

  /// No description provided for @sentenceLearningLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading sentence...'**
  String get sentenceLearningLoading;

  /// No description provided for @sessionSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Summary'**
  String get sessionSummaryTitle;

  /// No description provided for @sessionSummaryStatTotalItems.
  ///
  /// In en, this message translates to:
  /// **'Total Items'**
  String get sessionSummaryStatTotalItems;

  /// No description provided for @sessionSummaryStatCompletedItems.
  ///
  /// In en, this message translates to:
  /// **'Completed Items'**
  String get sessionSummaryStatCompletedItems;

  /// No description provided for @sessionSummaryStatAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get sessionSummaryStatAccuracy;

  /// No description provided for @sessionSummaryStatCorrectAnswers.
  ///
  /// In en, this message translates to:
  /// **'Correct Answers'**
  String get sessionSummaryStatCorrectAnswers;

  /// No description provided for @sessionSummaryStatSessionId.
  ///
  /// In en, this message translates to:
  /// **'Session ID'**
  String get sessionSummaryStatSessionId;

  /// No description provided for @sessionSummarySubtitleNoSession.
  ///
  /// In en, this message translates to:
  /// **'The session is complete. Review your results and submit your report.'**
  String get sessionSummarySubtitleNoSession;

  /// No description provided for @sessionSummarySubtitleWithMode.
  ///
  /// In en, this message translates to:
  /// **'The {mode} session is complete. Submit your report to unlock the next session.'**
  String sessionSummarySubtitleWithMode(String mode);

  /// No description provided for @sessionSummaryHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Great work finishing today\'s learning.'**
  String get sessionSummaryHeroTitle;

  /// No description provided for @sessionSummaryResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Result'**
  String get sessionSummaryResultTitle;

  /// No description provided for @sessionSummaryResultDescription.
  ///
  /// In en, this message translates to:
  /// **'Summary of this session.'**
  String get sessionSummaryResultDescription;

  /// No description provided for @sessionSummaryCoachNote.
  ///
  /// In en, this message translates to:
  /// **'Coach note: Your mission sentence pronunciation improved. Keep practicing speaking in the next session too.'**
  String get sessionSummaryCoachNote;

  /// No description provided for @sessionSummaryNextRecommendationTitle.
  ///
  /// In en, this message translates to:
  /// **'Next Recommendation'**
  String get sessionSummaryNextRecommendationTitle;

  /// No description provided for @sessionSummaryNextRecommendationDescription.
  ///
  /// In en, this message translates to:
  /// **'Maintain momentum with short repetition practice.'**
  String get sessionSummaryNextRecommendationDescription;

  /// No description provided for @sessionSummaryNextRecommendationBody.
  ///
  /// In en, this message translates to:
  /// **'After submitting your report, the next study session will open. Advanced content is released after admin review.'**
  String get sessionSummaryNextRecommendationBody;

  /// No description provided for @sessionSummarySecondaryToSelect.
  ///
  /// In en, this message translates to:
  /// **'Back to selection'**
  String get sessionSummarySecondaryToSelect;

  /// No description provided for @sessionSummaryPrimaryToReportPreview.
  ///
  /// In en, this message translates to:
  /// **'Go to Report Preview'**
  String get sessionSummaryPrimaryToReportPreview;

  /// No description provided for @loginFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String loginFailedWithError(String error);

  /// No description provided for @loginContinueForDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Continue for Development'**
  String get loginContinueForDevelopment;

  /// No description provided for @loginReleaseNote.
  ///
  /// In en, this message translates to:
  /// **'Phone authentication will be enabled in release.'**
  String get loginReleaseNote;

  /// No description provided for @studyModeBackToSelection.
  ///
  /// In en, this message translates to:
  /// **'Back to Selection'**
  String get studyModeBackToSelection;

  /// No description provided for @reportPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Preview'**
  String get reportPreviewTitle;

  /// No description provided for @reportPreviewSessionInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Info'**
  String get reportPreviewSessionInfoTitle;

  /// No description provided for @reportPreviewSessionId.
  ///
  /// In en, this message translates to:
  /// **'Session ID: {sessionId}'**
  String reportPreviewSessionId(String sessionId);

  /// No description provided for @reportPreviewContentSet.
  ///
  /// In en, this message translates to:
  /// **'Content Set: {contentSetId}'**
  String reportPreviewContentSet(String contentSetId);

  /// No description provided for @reportPreviewLearningMode.
  ///
  /// In en, this message translates to:
  /// **'Learning Mode: {mode}'**
  String reportPreviewLearningMode(String mode);

  /// No description provided for @reportPreviewSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary: {summary}'**
  String reportPreviewSummary(String summary);

  /// No description provided for @reportPreviewChecklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Before Submit'**
  String get reportPreviewChecklistTitle;

  /// No description provided for @reportPreviewChecklistBody.
  ///
  /// In en, this message translates to:
  /// **'1) Summarize today\'s learning in 1-2 sentences.\n2) Check listening and speaking practice completion.\n3) After submit, you can start the next session.'**
  String get reportPreviewChecklistBody;

  /// No description provided for @reportPreviewSecondaryToSummary.
  ///
  /// In en, this message translates to:
  /// **'Back to Summary'**
  String get reportPreviewSecondaryToSummary;

  /// No description provided for @reportPreviewPrimaryToReport.
  ///
  /// In en, this message translates to:
  /// **'Write Report'**
  String get reportPreviewPrimaryToReport;

  /// No description provided for @reportGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Gate'**
  String get reportGateTitle;

  /// No description provided for @reportGateRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh Status'**
  String get reportGateRefreshTooltip;

  /// No description provided for @reportGateBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Learning is blocked until this week\'s report is submitted.'**
  String get reportGateBlockedMessage;

  /// No description provided for @reportGateOpenMessage.
  ///
  /// In en, this message translates to:
  /// **'No report requirement now. You can continue learning.'**
  String get reportGateOpenMessage;

  /// No description provided for @reportGateStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Gate Status'**
  String get reportGateStatusTitle;

  /// No description provided for @reportGateCurrentStage.
  ///
  /// In en, this message translates to:
  /// **'Current gate stage: {stage}'**
  String reportGateCurrentStage(String stage);

  /// No description provided for @reportGateNextStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Next Steps'**
  String get reportGateNextStepsTitle;

  /// No description provided for @reportGateNextStepsBody.
  ///
  /// In en, this message translates to:
  /// **'1) Review session summary.\n2) Write your reflection.\n3) Submit report and wait for admin review.'**
  String get reportGateNextStepsBody;

  /// No description provided for @reportGatePrimaryToPreview.
  ///
  /// In en, this message translates to:
  /// **'Go to Report Preview'**
  String get reportGatePrimaryToPreview;

  /// No description provided for @reportGatePrimaryToSelect.
  ///
  /// In en, this message translates to:
  /// **'Go to Selection'**
  String get reportGatePrimaryToSelect;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Report'**
  String get reportTitle;

  /// No description provided for @reportNoSessionBanner.
  ///
  /// In en, this message translates to:
  /// **'No active session. Report submission is unavailable.'**
  String get reportNoSessionBanner;

  /// No description provided for @reportAuthRequiredBanner.
  ///
  /// In en, this message translates to:
  /// **'Report submission requires an authenticated account.'**
  String get reportAuthRequiredBanner;

  /// No description provided for @reportChecklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Checklist'**
  String get reportChecklistTitle;

  /// No description provided for @reportChecklistListening.
  ///
  /// In en, this message translates to:
  /// **'I completed listening practice.'**
  String get reportChecklistListening;

  /// No description provided for @reportChecklistSpeaking.
  ///
  /// In en, this message translates to:
  /// **'I completed speaking practice.'**
  String get reportChecklistSpeaking;

  /// No description provided for @reportReflectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Reflection'**
  String get reportReflectionTitle;

  /// No description provided for @reportReflectionHint.
  ///
  /// In en, this message translates to:
  /// **'Write your reflection in 1-2 sentences.'**
  String get reportReflectionHint;

  /// No description provided for @reportSubmittedMessage.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. You can start the next learning.'**
  String get reportSubmittedMessage;

  /// No description provided for @reportSecondaryToSummary.
  ///
  /// In en, this message translates to:
  /// **'Back to Summary'**
  String get reportSecondaryToSummary;

  /// No description provided for @reportPrimaryDone.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get reportPrimaryDone;

  /// No description provided for @reportPrimarySubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get reportPrimarySubmit;

  /// No description provided for @reportSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Report submission failed. Please try again.'**
  String get reportSubmitFailed;

  /// No description provided for @flashSentenceLearningTitle.
  ///
  /// In en, this message translates to:
  /// **'Flash Sentence Learning'**
  String get flashSentenceLearningTitle;

  /// No description provided for @flashSentenceLearningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Build sentence fluency through short repeated cycles.'**
  String get flashSentenceLearningSubtitle;

  /// No description provided for @flashSentenceLearningProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Sentence {current} / {total}'**
  String flashSentenceLearningProgressLabel(int current, int total);

  /// No description provided for @flashSentenceLearningPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Sentence'**
  String get flashSentenceLearningPromptTitle;

  /// No description provided for @flashSentenceLearningPrimaryButton.
  ///
  /// In en, this message translates to:
  /// **'Go to Flash Sentence Test'**
  String get flashSentenceLearningPrimaryButton;

  /// No description provided for @flashWordLearningTitle.
  ///
  /// In en, this message translates to:
  /// **'Flash Word Learning'**
  String get flashWordLearningTitle;

  /// No description provided for @flashWordLearningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Build core vocabulary through short repeated cycles.'**
  String get flashWordLearningSubtitle;

  /// No description provided for @flashWordLearningProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Word {current} / {total}'**
  String flashWordLearningProgressLabel(int current, int total);

  /// No description provided for @flashWordLearningPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Word'**
  String get flashWordLearningPromptTitle;

  /// No description provided for @flashWordLearningPrimaryButton.
  ///
  /// In en, this message translates to:
  /// **'Go to Flash Word Test'**
  String get flashWordLearningPrimaryButton;

  /// No description provided for @sentenceTestChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Sentence Test - Choice'**
  String get sentenceTestChoiceTitle;

  /// No description provided for @sentenceTestChoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the Thai sentence that matches Korean.'**
  String get sentenceTestChoiceSubtitle;

  /// No description provided for @sentenceTestChoiceProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Question {current} / {total}'**
  String sentenceTestChoiceProgressLabel(int current, int total);

  /// No description provided for @sentenceTestChoicePromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose from Korean prompt'**
  String get sentenceTestChoicePromptTitle;

  /// No description provided for @sentenceTestChoicePrimaryButton.
  ///
  /// In en, this message translates to:
  /// **'Go to Speaking Test'**
  String get sentenceTestChoicePrimaryButton;

  /// No description provided for @flashSentenceTestChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Flash Sentence Test - Choice'**
  String get flashSentenceTestChoiceTitle;

  /// No description provided for @flashSentenceTestChoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the Thai sentence that matches Korean.'**
  String get flashSentenceTestChoiceSubtitle;

  /// No description provided for @flashSentenceTestChoiceProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Question {current} / {total}'**
  String flashSentenceTestChoiceProgressLabel(int current, int total);

  /// No description provided for @flashSentenceTestChoicePromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Translate Korean to Thai'**
  String get flashSentenceTestChoicePromptTitle;

  /// No description provided for @flashSentenceTestChoicePrimaryButton.
  ///
  /// In en, this message translates to:
  /// **'Go to Speaking Test'**
  String get flashSentenceTestChoicePrimaryButton;

  /// No description provided for @flashWordTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Flash Word Test'**
  String get flashWordTestTitle;

  /// No description provided for @flashWordTestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the meaning of the Thai word.'**
  String get flashWordTestSubtitle;

  /// No description provided for @flashWordTestProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Question {current} / {total}'**
  String flashWordTestProgressLabel(int current, int total);

  /// No description provided for @flashWordTestPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Check Word Meaning'**
  String get flashWordTestPromptTitle;

  /// No description provided for @flashWordTestPrimaryButton.
  ///
  /// In en, this message translates to:
  /// **'Finish Test'**
  String get flashWordTestPrimaryButton;

  /// No description provided for @sentenceTestSpeakingTitle.
  ///
  /// In en, this message translates to:
  /// **'Sentence Test - Speaking'**
  String get sentenceTestSpeakingTitle;

  /// No description provided for @sentenceTestSpeakingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Speak the prompt sentence and review your similarity score.'**
  String get sentenceTestSpeakingSubtitle;

  /// No description provided for @sentenceTestSpeakingProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Speaking {current} / {total}'**
  String sentenceTestSpeakingProgressLabel(int current, int total);

  /// No description provided for @sentenceTestSpeakingPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Speaking Prompt'**
  String get sentenceTestSpeakingPromptTitle;

  /// No description provided for @sentenceTestSpeakingPrimaryButton.
  ///
  /// In en, this message translates to:
  /// **'Finish Test'**
  String get sentenceTestSpeakingPrimaryButton;

  /// No description provided for @flashSentenceTestSpeakingTitle.
  ///
  /// In en, this message translates to:
  /// **'Flash Sentence Test - Speaking'**
  String get flashSentenceTestSpeakingTitle;

  /// No description provided for @flashSentenceTestSpeakingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Speak quickly and review your score.'**
  String get flashSentenceTestSpeakingSubtitle;

  /// No description provided for @flashSentenceTestSpeakingProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Speaking {current} / {total}'**
  String flashSentenceTestSpeakingProgressLabel(int current, int total);

  /// No description provided for @flashSentenceTestSpeakingPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Speaking Prompt'**
  String get flashSentenceTestSpeakingPromptTitle;

  /// No description provided for @flashSentenceTestSpeakingPrimaryButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get flashSentenceTestSpeakingPrimaryButton;

  /// No description provided for @speakingNoRecordingData.
  ///
  /// In en, this message translates to:
  /// **'No recording data. Please try again.'**
  String get speakingNoRecordingData;

  /// No description provided for @speakingDevModePass.
  ///
  /// In en, this message translates to:
  /// **'In development mode, this is marked as completed.'**
  String get speakingDevModePass;

  /// No description provided for @speakingSelectAsrPolicyFirst.
  ///
  /// In en, this message translates to:
  /// **'Select ASR policy from learning selection first.'**
  String get speakingSelectAsrPolicyFirst;

  /// No description provided for @speakingServerOnlyRequiresNetwork.
  ///
  /// In en, this message translates to:
  /// **'Server STT only mode. Connect network and try again.'**
  String get speakingServerOnlyRequiresNetwork;

  /// No description provided for @speakingNetworkOrServerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not evaluate speech due to network/server issue.'**
  String get speakingNetworkOrServerFailed;

  /// No description provided for @speakingServerAndOnDeviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Server and on-device ASR are unavailable. {reason}'**
  String speakingServerAndOnDeviceUnavailable(String reason);

  /// No description provided for @speakingOnDeviceSaved.
  ///
  /// In en, this message translates to:
  /// **'Processed by on-device ASR.'**
  String get speakingOnDeviceSaved;

  /// No description provided for @speakingOnDeviceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save on-device result. Try again.'**
  String get speakingOnDeviceSaveFailed;

  /// No description provided for @guidePrinciplesTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning & Report Principles'**
  String get guidePrinciplesTitle;

  /// No description provided for @guideStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Flow Steps'**
  String get guideStepsTitle;

  /// No description provided for @guidePrinciple1.
  ///
  /// In en, this message translates to:
  /// **'Learning content uses bundled sentence, word, and audio data first.'**
  String get guidePrinciple1;

  /// No description provided for @guidePrinciple2.
  ///
  /// In en, this message translates to:
  /// **'Learning history is cumulative and preserved before report submit.'**
  String get guidePrinciple2;

  /// No description provided for @guidePrinciple3.
  ///
  /// In en, this message translates to:
  /// **'If you choose start new, the previous active session is abandoned.'**
  String get guidePrinciple3;

  /// No description provided for @guidePrinciple4.
  ///
  /// In en, this message translates to:
  /// **'Report submission is learner-driven and can be done anytime in session.'**
  String get guidePrinciple4;

  /// No description provided for @guidePrinciple5.
  ///
  /// In en, this message translates to:
  /// **'Retry and sync paths are kept for network and error resilience.'**
  String get guidePrinciple5;

  /// No description provided for @guideStep1.
  ///
  /// In en, this message translates to:
  /// **'Choose category, level, and mode.'**
  String get guideStep1;

  /// No description provided for @guideStep2.
  ///
  /// In en, this message translates to:
  /// **'Proceed sentence/word learning and use resume as needed.'**
  String get guideStep2;

  /// No description provided for @guideStep3.
  ///
  /// In en, this message translates to:
  /// **'Complete tests and review summary.'**
  String get guideStep3;

  /// No description provided for @guideStep4.
  ///
  /// In en, this message translates to:
  /// **'Submit cumulative report at your chosen timing.'**
  String get guideStep4;

  /// No description provided for @learningSelectActiveSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'There is an active learning session.'**
  String get learningSelectActiveSessionTitle;

  /// No description provided for @learningSelectStartNewButton.
  ///
  /// In en, this message translates to:
  /// **'Start New'**
  String get learningSelectStartNewButton;

  /// No description provided for @learningSelectStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting session...'**
  String get learningSelectStarting;

  /// No description provided for @learningSelectConfirmStartNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a new learning session?'**
  String get learningSelectConfirmStartNewTitle;

  /// No description provided for @learningSelectConfirmStartNewMessage.
  ///
  /// In en, this message translates to:
  /// **'Current session will be abandoned. If you want to continue it, cancel and tap resume.'**
  String get learningSelectConfirmStartNewMessage;

  /// No description provided for @learningSelectConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get learningSelectConfirmCancel;

  /// No description provided for @learningSelectConfirmStartNew.
  ///
  /// In en, this message translates to:
  /// **'Start New'**
  String get learningSelectConfirmStartNew;

  /// No description provided for @learningSelectAsrPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Speech Recognition Policy'**
  String get learningSelectAsrPolicyTitle;

  /// No description provided for @learningSelectAsrPolicyIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose speech recognition mode. You can change it later.'**
  String get learningSelectAsrPolicyIntro;

  /// No description provided for @learningSelectAsrPolicyServerOnly.
  ///
  /// In en, this message translates to:
  /// **'Server STT Only'**
  String get learningSelectAsrPolicyServerOnly;

  /// No description provided for @learningSelectAsrPolicyOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline Support'**
  String get learningSelectAsrPolicyOffline;

  /// No description provided for @learningSelectAsrPolicyServerOnlyDesc.
  ///
  /// In en, this message translates to:
  /// **'No local model download. Offline evaluation is unavailable.'**
  String get learningSelectAsrPolicyServerOnlyDesc;

  /// No description provided for @learningSelectAsrPolicyOfflineDesc.
  ///
  /// In en, this message translates to:
  /// **'With local ASR, speaking evaluation can continue offline.'**
  String get learningSelectAsrPolicyOfflineDesc;

  /// No description provided for @learningSelectAsrSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get learningSelectAsrSyncNow;

  /// No description provided for @learningSelectAsrPendingSync.
  ///
  /// In en, this message translates to:
  /// **'{count} offline results pending sync.'**
  String learningSelectAsrPendingSync(int count);

  /// No description provided for @learningSelectAsrNoPendingSync.
  ///
  /// In en, this message translates to:
  /// **'No pending offline sync.'**
  String get learningSelectAsrNoPendingSync;

  /// No description provided for @learningSelectCategoryDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily Conversation'**
  String get learningSelectCategoryDaily;

  /// No description provided for @learningSelectCategoryMission.
  ///
  /// In en, this message translates to:
  /// **'Mission'**
  String get learningSelectCategoryMission;

  /// No description provided for @learningSelectLevelBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get learningSelectLevelBeginner;

  /// No description provided for @learningSelectLevelIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get learningSelectLevelIntermediate;

  /// No description provided for @learningSelectLevelAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get learningSelectLevelAdvanced;

  /// No description provided for @learningSelectModeSentenceLearning.
  ///
  /// In en, this message translates to:
  /// **'Sentence Learning'**
  String get learningSelectModeSentenceLearning;

  /// No description provided for @learningSelectModeSentenceTest.
  ///
  /// In en, this message translates to:
  /// **'Sentence Test'**
  String get learningSelectModeSentenceTest;

  /// No description provided for @learningSelectModeFlashWordLearning.
  ///
  /// In en, this message translates to:
  /// **'Flash Word Learning'**
  String get learningSelectModeFlashWordLearning;

  /// No description provided for @learningSelectModeFlashWordTest.
  ///
  /// In en, this message translates to:
  /// **'Flash Word Test'**
  String get learningSelectModeFlashWordTest;

  /// No description provided for @learningSelectModeFlashSentenceLearning.
  ///
  /// In en, this message translates to:
  /// **'Flash Sentence Learning'**
  String get learningSelectModeFlashSentenceLearning;

  /// No description provided for @learningSelectModeFlashSentenceTest.
  ///
  /// In en, this message translates to:
  /// **'Flash Sentence Test'**
  String get learningSelectModeFlashSentenceTest;

  /// No description provided for @learningSelectUnselected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get learningSelectUnselected;

  /// No description provided for @learningSelectSelectionSummary.
  ///
  /// In en, this message translates to:
  /// **'Current selection: category {category} / level {level} / mode {mode}'**
  String learningSelectSelectionSummary(
    String category,
    String level,
    String mode,
  );

  /// No description provided for @learningSelectModeDescSentenceLearning.
  ///
  /// In en, this message translates to:
  /// **'Study sentence with pronunciation and hints step by step.'**
  String get learningSelectModeDescSentenceLearning;

  /// No description provided for @learningSelectModeDescSentenceTest.
  ///
  /// In en, this message translates to:
  /// **'Validate sentence understanding via choice and speaking.'**
  String get learningSelectModeDescSentenceTest;

  /// No description provided for @learningSelectModeDescFlashWordLearning.
  ///
  /// In en, this message translates to:
  /// **'Memorize core words quickly with flash repetition.'**
  String get learningSelectModeDescFlashWordLearning;

  /// No description provided for @learningSelectModeDescFlashWordTest.
  ///
  /// In en, this message translates to:
  /// **'Check word memory quickly with short tests.'**
  String get learningSelectModeDescFlashWordTest;

  /// No description provided for @learningSelectModeDescFlashSentenceLearning.
  ///
  /// In en, this message translates to:
  /// **'Practice sentences with high-tempo flash cards.'**
  String get learningSelectModeDescFlashSentenceLearning;

  /// No description provided for @learningSelectModeDescFlashSentenceTest.
  ///
  /// In en, this message translates to:
  /// **'Validate sentence comprehension and speaking in quick cycles.'**
  String get learningSelectModeDescFlashSentenceTest;

  /// No description provided for @learningSelectModeDescNone.
  ///
  /// In en, this message translates to:
  /// **'Select a mode to see guidance.'**
  String get learningSelectModeDescNone;

  /// No description provided for @sentenceLearningPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Preparing sentence learning content.'**
  String get sentenceLearningPlaceholder;

  /// No description provided for @sentenceLearningPronunciationLabel.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation'**
  String get sentenceLearningPronunciationLabel;

  /// No description provided for @sentenceLearningHintLabel.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get sentenceLearningHintLabel;

  /// No description provided for @sentenceLearningProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress: {current} / {total}'**
  String sentenceLearningProgress(int current, int total);

  /// No description provided for @sentenceLearningSessionCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Sentence learning session is complete.'**
  String get sentenceLearningSessionCompletedMessage;

  /// No description provided for @sentenceLearningCompleteAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Complete and Continue'**
  String get sentenceLearningCompleteAndContinue;

  /// No description provided for @adminContactLabel.
  ///
  /// In en, this message translates to:
  /// **'Admin Contact'**
  String get adminContactLabel;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Learner Login'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use development mode login until phone auth is enabled.'**
  String get loginSubtitle;

  /// No description provided for @approvalPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Approval Pending'**
  String get approvalPendingTitle;

  /// No description provided for @approvalPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Login is complete. Admin approval is required before learning starts.'**
  String get approvalPendingMessage;

  /// No description provided for @refreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh Status'**
  String get refreshStatus;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// No description provided for @blockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Access Restricted'**
  String get blockedTitle;

  /// No description provided for @blockedMessage.
  ///
  /// In en, this message translates to:
  /// **'This account is currently restricted. Please contact admin.'**
  String get blockedMessage;

  /// No description provided for @bootstrapMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking your learning status...'**
  String get bootstrapMessage;

  /// No description provided for @learningBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Temporarily Blocked'**
  String get learningBlockedTitle;

  /// No description provided for @learningBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Learning is paused until mandatory report is submitted.'**
  String get learningBlockedMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
