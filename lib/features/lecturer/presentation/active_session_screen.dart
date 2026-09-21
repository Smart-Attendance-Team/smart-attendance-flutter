import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import 'live_roster_screen.dart';

/// GET /sessions/{id}/qr -> {token, expires_in_seconds: 20}
/// POST /sessions/{id}/close to finish.
class ActiveSessionScreen extends StatefulWidget {
  final String sessionId;
  final String sessionTitle;
  const ActiveSessionScreen({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  final _api = ApiClient();
  Timer? _timer;
  String? _token;
  int _seconds = 20;
  bool _loading = true;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _path => '/sessions/${widget.sessionId}/qr';

  Future<void> _fetch() async {
    try {
      final res = await _api.client.get(_path);
      final map = ApiClient.asMap(res.data);
      if (mounted) {
        setState(() {
          _token = map['token']?.toString() ?? map['qr']?.toString();
          _seconds = (map['expires_in_seconds'] is int)
              ? map['expires_in_seconds'] as int
              : 20;
          _loading = false;
        });
        _restartTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : tr('qr_none'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _refresh() async {
    try {
      final res = await _api.client.get(_path);
      final next = ApiClient.asMap(res.data)['token']?.toString();
      if (mounted && next != null && next.isNotEmpty) {
        setState(() => _token = next);
      }
    } catch (_) {
      // Keep the previous token on screen.
    } finally {
      if (mounted) setState(() => _seconds = 20);
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_seconds <= 1) {
        _refresh();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _close() async {
    setState(() => _ending = true);
    try {
      await _api.postMap('/sessions/${widget.sessionId}/close');
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
        setState(() => _ending = false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('cant_load'))),
        );
        setState(() => _ending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionTitle),
        actions: [
          IconButton(
            tooltip: tr('roster'),
            icon: const Icon(Icons.groups_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    LiveRosterScreen(sessionId: widget.sessionId),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (_loading)
                AppLoading(message: tr('qr_loading'))
              else if (_token != null && _token!.isNotEmpty)
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      QrImageView(
                        data: _token!,
                        version: QrVersions.auto,
                        size: 230,
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        _token!,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    const Icon(
                      Icons.qr_code_2_rounded,
                      size: 100,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: tr('qr_retry'),
                      icon: Icons.refresh_rounded,
                      outlined: true,
                      onPressed: () {
                        setState(() => _loading = true);
                        _fetch();
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tr('qr_refresh', {'n': ltr(_seconds)}),
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AppButton(
                label: tr('end_session'),
                icon: Icons.stop_circle_outlined,
                loading: _ending,
                onPressed: _close,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
