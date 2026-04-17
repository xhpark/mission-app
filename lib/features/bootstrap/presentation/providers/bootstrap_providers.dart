import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_services.dart';
import '../../data/repositories/bootstrap_repository.dart';

final bootstrapRepositoryProvider = Provider<BootstrapRepository>((ref) {
  return BootstrapRepository(ref.watch(firebaseFunctionsProvider));
});
