import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_services.dart';
import '../../data/repositories/study_session_repository.dart';

final studySessionRepositoryProvider = Provider<StudySessionRepository>((ref) {
  return StudySessionRepository(ref.watch(firebaseFunctionsProvider));
});
