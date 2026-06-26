import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_services.dart';

enum LearnerRosterStatus { notRegistered, pendingApproval, approved, blocked }

LearnerRosterStatus _statusFromString(String value) => switch (value) {
  'approved' => LearnerRosterStatus.approved,
  'blocked' => LearnerRosterStatus.blocked,
  'pending_approval' => LearnerRosterStatus.pendingApproval,
  _ => LearnerRosterStatus.notRegistered,
};

class LearnerRosterEntry {
  const LearnerRosterEntry({
    required this.rosterId,
    required this.name,
    required this.phone,
    required this.status,
    required this.matchedEmail,
  });

  final String rosterId;
  final String name;
  final String phone;
  final LearnerRosterStatus status;
  final String? matchedEmail;

  factory LearnerRosterEntry.fromMap(Map<String, dynamic> map) {
    final email = map['matchedEmail']?.toString();
    return LearnerRosterEntry(
      rosterId: map['rosterId']?.toString() ?? '',
      name: map['name']?.toString() ?? '-',
      phone: map['phone']?.toString() ?? '-',
      status: _statusFromString(map['status']?.toString() ?? ''),
      matchedEmail: (email == null || email.isEmpty) ? null : email,
    );
  }
}

final learnerRosterRepositoryProvider = Provider<LearnerRosterRepository>((
  ref,
) {
  return LearnerRosterRepository(ref);
});

class LearnerRosterRepository {
  LearnerRosterRepository(this._ref);

  final Ref _ref;

  Future<({int added, int updated})> addEntries({
    required String adminUserId,
    required List<({String name, String phone})> entries,
  }) async {
    final result = await _ref
        .read(firebaseFunctionsProvider)
        .httpsCallable('addLearnerRosterEntries')
        .call(<String, dynamic>{
          'adminUserId': adminUserId,
          'entries': entries
              .map((e) => {'name': e.name, 'phone': e.phone})
              .toList(),
        });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (
      added: (data['added'] as num?)?.toInt() ?? 0,
      updated: (data['updated'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<LearnerRosterEntry>> getRoster({
    required String adminUserId,
  }) async {
    final result = await _ref
        .read(firebaseFunctionsProvider)
        .httpsCallable('getLearnerRoster')
        .call(<String, dynamic>{'adminUserId': adminUserId});
    final data = Map<String, dynamic>.from(result.data as Map);
    final rawEntries = (data['entries'] as List?) ?? const [];
    return rawEntries
        .map(
          (e) => LearnerRosterEntry.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> deleteEntry({
    required String adminUserId,
    required String rosterId,
  }) async {
    await _ref
        .read(firebaseFunctionsProvider)
        .httpsCallable('deleteLearnerRosterEntry')
        .call(<String, dynamic>{
          'adminUserId': adminUserId,
          'rosterId': rosterId,
        });
  }
}
