import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/today_link_repository.dart';

final todayLinkControllerProvider =
    AsyncNotifierProvider<TodayLinkController, TodayLink?>(
  TodayLinkController.new,
);

class TodayLinkController extends AsyncNotifier<TodayLink?> {
  @override
  Future<TodayLink?> build() async => null;

  Future<TodayLink> fetchTodayLink({String? dateKey}) async {
    state = const AsyncLoading();
    try {
      final link = await ref
          .read(todayLinkRepositoryProvider)
          .getTodayLink(dateKey: dateKey);
      state = AsyncData(link);
      return link;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
