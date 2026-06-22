import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/content_audio_cache_invalidator.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateFirebaseAppCheck();
  await ContentAudioCacheInvalidator.invalidateIfContentChanged();

  runApp(const ProviderScope(child: MissionApp()));
}

Future<void> _activateFirebaseAppCheck() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  const enableDebugAppCheck = bool.fromEnvironment('ENABLE_FIREBASE_APP_CHECK');
  if (!kReleaseMode && !enableDebugAppCheck) {
    return;
  }

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kReleaseMode
        ? const AndroidPlayIntegrityProvider()
        : const AndroidDebugProvider(),
  );
}
