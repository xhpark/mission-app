import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_services.dart';
import '../../data/repositories/sentence_learning_repository.dart';

final sentenceLearningRepositoryProvider =
    Provider<SentenceLearningRepository>((ref) {
  return SentenceLearningRepository(ref.watch(firebaseFunctionsProvider));
});
