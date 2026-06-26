import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_services.dart';

class TodayLink {
  const TodayLink({
    required this.exists,
    required this.dateKey,
    required this.url,
    required this.title,
  });

  final bool exists;
  final String dateKey;
  final String? url;
  final String? title;

  factory TodayLink.fromMap(Map<String, dynamic> map) {
    return TodayLink(
      exists: map['exists'] == true,
      dateKey: map['dateKey']?.toString() ?? '',
      url: map['url']?.toString(),
      title: map['title']?.toString(),
    );
  }
}

class TodayLinkLearnerClicks {
  const TodayLinkLearnerClicks({
    required this.userId,
    required this.name,
    required this.email,
    required this.clickCount,
    required this.clickedAt,
  });

  final String userId;
  final String name;
  final String email;
  final int clickCount;
  final List<DateTime> clickedAt;

  factory TodayLinkLearnerClicks.fromMap(Map<String, dynamic> map) {
    final rawClickedAt = (map['clickedAt'] as List?) ?? const [];
    return TodayLinkLearnerClicks(
      userId: map['userId']?.toString() ?? '',
      name: map['name']?.toString() ?? '-',
      email: map['email']?.toString() ?? '',
      clickCount: (map['clickCount'] as num?)?.toInt() ?? 0,
      clickedAt: rawClickedAt
          .map((e) => DateTime.tryParse(e.toString()))
          .whereType<DateTime>()
          .toList(),
    );
  }
}

class TodayLinkClicks {
  const TodayLinkClicks({
    required this.dateKey,
    required this.totalClicks,
    required this.totalLearners,
    required this.learners,
  });

  final String dateKey;
  final int totalClicks;
  final int totalLearners;
  final List<TodayLinkLearnerClicks> learners;

  factory TodayLinkClicks.fromMap(Map<String, dynamic> map) {
    final rawLearners = (map['learners'] as List?) ?? const [];
    return TodayLinkClicks(
      dateKey: map['dateKey']?.toString() ?? '',
      totalClicks: (map['totalClicks'] as num?)?.toInt() ?? 0,
      totalLearners: (map['totalLearners'] as num?)?.toInt() ?? 0,
      learners: rawLearners
          .map(
            (e) => TodayLinkLearnerClicks.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

final todayLinkRepositoryProvider = Provider<TodayLinkRepository>((ref) {
  return TodayLinkRepository(ref);
});

class TodayLinkRepository {
  TodayLinkRepository(this._ref);

  final Ref _ref;

  Future<TodayLink> getTodayLink({String? dateKey}) async {
    final result = await _ref
        .read(firebaseFunctionsProvider)
        .httpsCallable('getTodayLink')
        .call(<String, dynamic>{'dateKey': ?dateKey});
    return TodayLink.fromMap(Map<String, dynamic>.from(result.data as Map));
  }

  Future<void> setTodayLink({
    required String adminUserId,
    required String url,
    required String title,
    String? dateKey,
  }) async {
    await _ref.read(firebaseFunctionsProvider).httpsCallable('setTodayLink').call(
      <String, dynamic>{
        'adminUserId': adminUserId,
        'url': url,
        'title': title,
        'dateKey': ?dateKey,
      },
    );
  }

  Future<void> recordTodayLinkClick({String? dateKey}) async {
    await _ref.read(firebaseFunctionsProvider).httpsCallable('recordTodayLinkClick').call(
      <String, dynamic>{'dateKey': ?dateKey},
    );
  }

  Future<TodayLinkClicks> getTodayLinkClicks({
    required String adminUserId,
    String? dateKey,
  }) async {
    final result = await _ref
        .read(firebaseFunctionsProvider)
        .httpsCallable('getTodayLinkClicks')
        .call(<String, dynamic>{'adminUserId': adminUserId, 'dateKey': ?dateKey});
    return TodayLinkClicks.fromMap(Map<String, dynamic>.from(result.data as Map));
  }
}
