import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_id_service.dart';

const firebaseFunctionsRegion = 'asia-northeast3';

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instanceFor(region: firebaseFunctionsRegion);
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final deviceIdServiceProvider = Provider<DeviceIdService>((ref) {
  return DeviceIdService();
});
