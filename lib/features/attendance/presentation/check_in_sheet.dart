import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ui.dart';

/// Student scans the rotating session QR.
/// POST /attendance/scan {token} -> the backend binds the record to the
/// logged-in student and stores it (present/late).
///  200 {accepted: true, duplicate?, attendance_status, minutes_late,
///       attendance_timestamp}
///  400/403/429 {accepted: false, reason}
///
/// After every scan the camera STOPS and a full result page is shown
/// (registered / duplicate / rejected + why). Nothing is auto-retried.
class CheckInSheet extends StatefulWidget {
  final void Function(String status) onSuccess;

  const CheckInSheet({super.key, required this.onSuccess});

  @override
  State<CheckInSheet> createState() => _CheckInSheetState();
}

class _ScanResult {
  final bool ok;
  final String status;
  final String message;
  final bool duplicate;
  final String? timestamp;

  const _ScanResult({
    required this.ok,
    required this.status,
    required this.message,
    this.duplicate = false,
    this.timestamp,
  });
}

class _CheckInSheetState extends State<CheckInSheet> {
  late final MobileScannerController _controller;
  final _api = ApiClient();
  bool _busy = false;
  _ScanResult? _result;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String token) async {
    if (_busy || _result != null) return;
    setState(() => _busy = true);
    await _controller.stop();
    try {
      // This POST is what records the student in the database
      // (bound to the logged-in account on the server side).
      final res = await _api.postMap(
        '/attendance/scan',
        data: {'token': token},
      );
      if (!mounted) return;
      if (res['accepted'] == true) {
        final dup = res['duplicate'] == true;
        setState(() {
          _busy = false;
          _result = _ScanResult(
            ok: true,
            status: res['attendance_status']?.toString() ?? 'present',
            message: dup ? tr('scan_dup') : tr('scan_ok'),
            duplicate: dup,
            timestamp: res['attendance_timestamp']?.toString(),
          );
        });
      } else {
        setState(() {
          _busy = false;
          _result = _ScanResult(
            ok: false,
            status: 'rejected',
            message: _friendly(res['reason']?.toString() ?? 'invalid_token'),
          );
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = _ScanResult(
          ok: false,
          status: 'rejected',
          message: e.message,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = _ScanResult(
          ok: false,
          status: 'rejected',
          message: tr('cant_load'),
        );
      });
    }
  }

  static String _friendly(String reason) {
    switch (reason) {
      case 'invalid_token':
        return tr('r_invalid');
      case 'expired_token':
        return tr('r_expired');
      case 'session_closed':
        return tr('r_closed');
      case 'not_enrolled':
        return tr('r_enrolled');
      case 'manually_recorded':
        return tr('r_manual');
      case 'too_many_attempts':
        return tr('r_many');
      default:
        return reason;
    }
  }

  Future<void> _retry() async {
    setState(() {
      _result = null;
      _busy = false;
    });
    await _controller.start();
  }

  void _done() {
    final r = _result;
    Navigator.pop(context);
    if (r != null && r.ok) widget.onSuccess(r.status);
  }

  void _onDetect(BarcodeCapture capture) {
    for (final code in capture.barcodes) {
      if (code.rawValue != null && code.rawValue!.isNotEmpty) {
        _send(code.rawValue!);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 16),
          if (_result == null) ...[
            Text(
              tr('scan_title'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('scan_sub'),
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 280,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),
                    Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    if (_busy)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ] else
            _ResultView(
              result: _result!,
              onRetry: _retry,
              onDone: _done,
            ),
        ],
      ),
    );
  }
}

/// Full result page shown after the scan (camera is off at this point).
class _ResultView extends StatelessWidget {
  final _ScanResult result;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  const _ResultView({
    required this.result,
    required this.onRetry,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final color = result.ok ? AppColors.success : AppColors.error;
    final bg = result.ok ? AppColors.successBg : AppColors.errorBg;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(
            result.ok
                ? (result.duplicate
                    ? Icons.done_all_rounded
                    : Icons.check_circle_rounded)
                : Icons.cancel_rounded,
            size: 56,
            color: color,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          result.message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StatusChip(status: result.status),
        if (result.timestamp != null &&
            result.timestamp!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            ltr(Format.date(result.timestamp)),
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (result.ok)
          AppButton(
            label: tr('done'),
            icon: Icons.check_rounded,
            onPressed: onDone,
          )
        else ...[
          AppButton(
            label: tr('retry_scan'),
            icon: Icons.qr_code_scanner_rounded,
            onPressed: onRetry,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: tr('close'),
            outlined: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ],
    );
  }
}

/// Opens [CheckInSheet]; on success shows a confirmation snackbar.
void showCheckIn(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => CheckInSheet(
      onSuccess: (status) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('marked', {'s': trStatus(status)})),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    ),
  );
}
