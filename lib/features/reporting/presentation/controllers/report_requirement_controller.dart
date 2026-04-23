import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final reportRequirementProvider =
    NotifierProvider<ReportRequirementController, bool>(
  ReportRequirementController.new,
);

class ReportRequirementController extends Notifier<bool> {
  static const _requiredKey = 'report_requirement.required';
  bool _hydrated = false;

  @override
  bool build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_hydrate());
    }
    return false;
  }

  void requireReport() {
    state = true;
    unawaited(_persist(true));
  }

  void markSubmitted() {
    state = false;
    unawaited(_persist(false));
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_requiredKey) ?? false;
  }

  Future<void> _persist(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_requiredKey, value);
  }
}
