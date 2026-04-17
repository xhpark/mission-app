import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_id_service.dart';

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instance;
});

final deviceIdServiceProvider = Provider<DeviceIdService>((ref) {
  return DeviceIdService();
});
