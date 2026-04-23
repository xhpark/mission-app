import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../features/bootstrap/presentation/controllers/bootstrap_controller.dart';
import '../../features/sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../firebase/firebase_providers.dart';

class DevDebugPanel extends ConsumerStatefulWidget {
  const DevDebugPanel({super.key});

  @override
  ConsumerState<DevDebugPanel> createState() => _DevDebugPanelState();
}

class _DevDebugPanelState extends ConsumerState<DevDebugPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    final developmentSession = ref.watch(developmentSessionProvider);
    final bootstrap = ref.watch(bootstrapControllerProvider).asData?.value;
    final studySession = ref.watch(currentStudySessionProvider);

    final route = _currentRoute(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final safeTop = MediaQuery.paddingOf(context).top;
    final panelWidth = math.max(160.0, math.min(320.0, screenWidth - 24));
    final userStatus = developmentSession
        ? '개발 세션'
        : (user == null
            ? '로그아웃 상태'
            : (user.isAnonymous ? '익명 사용자' : '인증 사용자'));

    return Positioned(
      right: 12,
      top: safeTop + 12,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: _expanded ? panelWidth : 150,
            padding: const EdgeInsets.all(12),
            child: _expanded
                ? _DebugPanelExpanded(
                    title: l10n?.debugPanelTitle ?? 'QA 디버그',
                    routeLabel: l10n?.debugRoute ?? '현재 경로',
                    userStatusLabel: l10n?.debugUserStatus ?? '사용자 상태',
                    sessionIdLabel: l10n?.debugSessionId ?? '세션 ID',
                    contentSetLabel: l10n?.debugContentSetId ?? '콘텐츠 세트 ID',
                    route: route,
                    userStatus: userStatus,
                    sessionId: studySession?.sessionId ?? '-',
                    contentSetId: studySession?.contentSetId ?? '-',
                    bootstrapStatus: bootstrap?.status ?? '-',
                  )
                : Text(
                    l10n?.debugPanelTitle ?? 'QA 디버그',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
          ),
        ),
      ),
    );
  }

  String _currentRoute(BuildContext context) {
    try {
      return GoRouterState.of(context).matchedLocation;
    } catch (_) {
      return '알 수 없음';
    }
  }
}

class _DebugPanelExpanded extends StatelessWidget {
  const _DebugPanelExpanded({
    required this.title,
    required this.routeLabel,
    required this.userStatusLabel,
    required this.sessionIdLabel,
    required this.contentSetLabel,
    required this.route,
    required this.userStatus,
    required this.sessionId,
    required this.contentSetId,
    required this.bootstrapStatus,
  });

  final String title;
  final String routeLabel;
  final String userStatusLabel;
  final String sessionIdLabel;
  final String contentSetLabel;
  final String route;
  final String userStatus;
  final String sessionId;
  final String contentSetId;
  final String bootstrapStatus;

  @override
  Widget build(BuildContext context) {
    final items = <({String key, String value})>[
      (key: routeLabel, value: route),
      (key: userStatusLabel, value: userStatus),
      (key: '부트스트랩 상태', value: bootstrapStatus),
      (key: sessionIdLabel, value: sessionId),
      (key: contentSetLabel, value: contentSetId),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${item.key}: ${item.value}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}
