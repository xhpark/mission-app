import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdService {
  static const _deviceIdKey = 'device_id';

  Future<String> getOrCreateDeviceId() async {
    final preferences = await SharedPreferences.getInstance();
    final savedId = preferences.getString(_deviceIdKey);
    if (savedId != null && savedId.isNotEmpty) {
      return savedId;
    }

    final generatedId =
        'device-${DateTime.now().millisecondsSinceEpoch.toString()}';
    await preferences.setString(_deviceIdKey, generatedId);
    return generatedId;
  }
}
