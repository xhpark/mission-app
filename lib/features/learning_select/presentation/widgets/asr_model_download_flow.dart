import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/asr_policy_controller.dart';
import '../../../../core/services/on_device_asr_model_downloader.dart';
import '../../../../core/services/on_device_asr_model_info.dart';

/// Entry point for the "폰 전용 인식" (on-device-only ASR) selector. The model
/// (~150MB) is never bundled into the app — it is downloaded on demand, gated
/// to Wi-Fi, only when a learner explicitly opts into this mode and consents.
/// See docs_content_update_checklist_2026-06-22.md for why it isn't bundled.
Future<void> handleOnDeviceAsrSelection(BuildContext context, WidgetRef ref) async {
  const downloader = OnDeviceAsrModelDownloader();

  if (await downloader.isModelInstalled()) {
    ref.read(asrPolicyProvider.notifier).chooseOnDeviceOnly();
    return;
  }
  if (!context.mounted) {
    return;
  }

  final approxMb = (OnDeviceAsrModelInfo.approxTotalBytes / 1024 / 1024).round();
  final shouldDownload = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('오프라인 음성 인식 모델 다운로드'),
      content: Text(
        '폰 전용 인식을 사용하려면 약 ${approxMb}MB 크기의 음성 인식 모델을 '
        'Wi-Fi 환경에서 다운로드해야 합니다.\n\n지금 다운로드하시겠습니까?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('다운로드'),
        ),
      ],
    ),
  );

  if (shouldDownload != true || !context.mounted) {
    return;
  }

  final result = await showDialog<AsrModelDownloadProgress>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _AsrModelDownloadProgressDialog(downloader: downloader),
  );

  if (!context.mounted) {
    return;
  }

  switch (result) {
    case AsrModelDownloadCompleted():
      ref.read(asrPolicyProvider.notifier).chooseOnDeviceOnly();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오프라인 음성 인식 모델 설치가 완료되었습니다.')),
      );
    case AsrModelDownloadFailed(reason: final reason):
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_failureMessage(reason))),
      );
    case null:
    default:
      // Dialog dismissed without a terminal result (e.g. cancelled mid-flight).
      break;
  }
}

String _failureMessage(AsrModelDownloadFailureReason reason) {
  switch (reason) {
    case AsrModelDownloadFailureReason.wifiRequired:
      return 'Wi-Fi에 연결한 후 다시 시도해 주세요.';
    case AsrModelDownloadFailureReason.manifestUnavailable:
      return '모델 정보를 불러오지 못했습니다. 네트워크 상태를 확인하고 다시 시도해 주세요.';
    case AsrModelDownloadFailureReason.checksumMismatch:
      return '다운로드한 모델 파일이 손상되었습니다. 다시 시도해 주세요.';
    case AsrModelDownloadFailureReason.storageFull:
      return '저장 공간이 부족합니다. 여유 공간을 확보한 후 다시 시도해 주세요.';
    case AsrModelDownloadFailureReason.networkError:
      return '다운로드 중 네트워크 오류가 발생했습니다. 다시 시도해 주세요.';
    case AsrModelDownloadFailureReason.cancelled:
      return '다운로드가 취소되었습니다.';
  }
}

class _AsrModelDownloadProgressDialog extends StatefulWidget {
  const _AsrModelDownloadProgressDialog({required this.downloader});

  final OnDeviceAsrModelDownloader downloader;

  @override
  State<_AsrModelDownloadProgressDialog> createState() =>
      _AsrModelDownloadProgressDialogState();
}

class _AsrModelDownloadProgressDialogState
    extends State<_AsrModelDownloadProgressDialog> {
  AsrModelDownloadProgress _progress = const AsrModelDownloadCheckingWifi();

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final stream = widget.downloader.download();
    await for (final progress in stream) {
      if (!mounted) {
        return;
      }
      setState(() => _progress = progress);
      if (progress is AsrModelDownloadCompleted || progress is AsrModelDownloadFailed) {
        Navigator.of(context).pop(progress);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return AlertDialog(
      title: const Text('모델 다운로드 중'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (progress is AsrModelDownloadInProgress) ...[
            LinearProgressIndicator(value: progress.fraction),
            const SizedBox(height: 12),
            Text(
              '${(progress.receivedBytes / 1024 / 1024).toStringAsFixed(1)} / '
              '${(progress.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB '
              '(${progress.fileIndex}/${progress.fileCount})',
            ),
          ] else ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(_statusLabel(progress)),
          ],
        ],
      ),
    );
  }

  String _statusLabel(AsrModelDownloadProgress progress) {
    switch (progress) {
      case AsrModelDownloadCheckingWifi():
        return 'Wi-Fi 연결을 확인하는 중...';
      case AsrModelDownloadFetchingManifest():
        return '다운로드 정보를 가져오는 중...';
      case AsrModelDownloadVerifying():
        return '다운로드한 파일을 검증하는 중...';
      case AsrModelDownloadCompleted():
        return '완료되었습니다.';
      case AsrModelDownloadFailed():
        return '다운로드에 실패했습니다.';
      case AsrModelDownloadInProgress():
        return '다운로드 중...';
    }
  }
}
