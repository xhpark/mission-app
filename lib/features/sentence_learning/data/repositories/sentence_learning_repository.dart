import 'package:cloud_functions/cloud_functions.dart';

import '../models/sentence_learning_item.dart';

class SentenceLearningRepository {
  SentenceLearningRepository(this._functions);

  final FirebaseFunctions _functions;

  Future<SentenceLearningItem> loadFirstItem({
    required String userId,
    required String sessionId,
    required String contentSetId,
  }) async {
    try {
      final callable = _functions.httpsCallable('getSentenceLearningItem');
      final response = await callable.call(<String, dynamic>{
        'userId': userId,
        'sessionId': sessionId,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      return SentenceLearningItem.fromJson(data);
    } on FirebaseFunctionsException {
      return SentenceLearningItem.fallback(
        sessionId: sessionId,
        contentSetId: contentSetId,
      );
    } catch (_) {
      return SentenceLearningItem.fallback(
        sessionId: sessionId,
        contentSetId: contentSetId,
      );
    }
  }

  Future<SentenceLearningItem> completeSentenceStudy({
    required String userId,
    required String sessionId,
    required String itemId,
    required String contentSetId,
    required int currentStep,
    required int totalSteps,
  }) async {
    try {
      final callable = _functions.httpsCallable('completeSentenceStudy');
      final response = await callable.call(<String, dynamic>{
        'userId': userId,
        'sessionId': sessionId,
        'itemId': itemId,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      return SentenceLearningItem.fromJson(data);
    } on FirebaseFunctionsException {
      if (currentStep >= totalSteps) {
        final fallback = SentenceLearningItem.fallback(
          sessionId: sessionId,
          contentSetId: contentSetId,
        );
        return SentenceLearningItem(
          sessionId: fallback.sessionId,
          contentSetId: fallback.contentSetId,
          itemId: itemId,
          order: currentStep,
          thaiText: fallback.thaiText,
          nativeText: fallback.nativeText,
          pronunciation: fallback.pronunciation,
          hint: fallback.hint,
          audioUrl: fallback.audioUrl,
          currentStep: totalSteps,
          totalSteps: totalSteps,
          sessionCompleted: true,
        );
      }

      return _fallbackAdvance(
        sessionId: sessionId,
        contentSetId: contentSetId,
        nextStep: currentStep + 1,
        totalSteps: totalSteps,
      );
    } catch (_) {
      if (currentStep >= totalSteps) {
        final fallback = SentenceLearningItem.fallback(
          sessionId: sessionId,
          contentSetId: contentSetId,
        );
        return SentenceLearningItem(
          sessionId: fallback.sessionId,
          contentSetId: fallback.contentSetId,
          itemId: itemId,
          order: currentStep,
          thaiText: fallback.thaiText,
          nativeText: fallback.nativeText,
          pronunciation: fallback.pronunciation,
          hint: fallback.hint,
          audioUrl: fallback.audioUrl,
          currentStep: totalSteps,
          totalSteps: totalSteps,
          sessionCompleted: true,
        );
      }

      return _fallbackAdvance(
        sessionId: sessionId,
        contentSetId: contentSetId,
        nextStep: currentStep + 1,
        totalSteps: totalSteps,
      );
    }
  }

  SentenceLearningItem _fallbackAdvance({
    required String sessionId,
    required String contentSetId,
    required int nextStep,
    required int totalSteps,
  }) {
    const fallbackItems = <({
      String thaiText,
      String nativeText,
      String pronunciation,
      String hint,
    })>[
      (
        thaiText: 'Sawasdee krap',
        nativeText: 'Hello.',
        pronunciation: 'sa-wat-dee krap',
        hint: 'A polite and simple Thai greeting used in everyday conversation.',
      ),
      (
        thaiText: 'Khob khun krap',
        nativeText: 'Thank you.',
        pronunciation: 'khob-khun krap',
        hint: 'A polite phrase used to express thanks.',
      ),
      (
        thaiText: 'Pai duay kan',
        nativeText: 'Let us go together.',
        pronunciation: 'pai duay kan',
        hint: 'A simple invitation phrase for moving together.',
      ),
    ];

    final index = (nextStep - 1).clamp(0, fallbackItems.length - 1) as int;
    final item = fallbackItems[index];

    return SentenceLearningItem(
      sessionId: sessionId,
      contentSetId: contentSetId,
      itemId: '$contentSetId-intro-$nextStep',
      order: nextStep,
      thaiText: item.thaiText,
      nativeText: item.nativeText,
      pronunciation: item.pronunciation,
      hint: item.hint,
      audioUrl: '',
      currentStep: nextStep,
      totalSteps: totalSteps,
      sessionCompleted: false,
    );
  }
}
