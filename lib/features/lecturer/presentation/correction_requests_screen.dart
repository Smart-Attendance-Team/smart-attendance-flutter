import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ui.dart';

/// GET /corrections/pending -> PendingCorrection[]
/// PATCH /corrections/{id} {decision, review_reason}
class CorrectionRequestsScreen extends StatefulWidget {
  const CorrectionRequestsScreen({super.key});

  @override
  State<CorrectionRequestsScreen> createState() =>
      _CorrectionRequestsScreenState();
}

class _CorrectionRequestsScreenState extends State<CorrectionRequestsScreen> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getList('/corrections/pending');
  }

  /// Manual refresh with visible confirmation (see refreshWithToast).
  Future<bool> _reload() {
    final future = _api.getList('/corrections/pending');
    setState(() {
      _future = future;
    });
    return future.then((_) => true).catchError((_) => false);
  }

  Future<void> _decide(int id, String decision) async {
    final reason = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          tr(
            'decide_title',
            {
              'd': decision == 'approved' ? tr('approve') : tr('reject'),
              'id': ltr(id),
            },
          ),
        ),
        content: SingleChildScrollView(
          child: AppField(
            controller: reason,
            label: tr('review_min'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(context, reason.text.trim()),
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );
    reason.dispose();
    if (value == null || value.length < 3) {
      if (value != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('review_need3'))),
        );
      }
      return;
    }
    try {
      await _api.patchMap(
        '/corrections/$id',
        data: {'decision': decision, 'review_reason': value},
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('decision_saved'))),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('cant_load'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('corr_rev')),
        actions: [
          IconButton(
            onPressed: () => refreshWithToast(context, _reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AppLoading(message: tr('req_loading'));
          }
          if (snapshot.hasError) {
            final err = snapshot.error;
            return AppError(
              message: err is ApiException
                  ? err.message
                  : tr('cant_load'),
              onRetry: _reload,
            );
          }
          final items = (snapshot.data ?? const [])
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
          if (items.isEmpty) {
            return AppEmpty(
              message: tr('no_pending'),
              icon: Icons.mark_email_read_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = items[i];
              final id = r['request_id'] ?? r['id'];
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(
                            Icons.person_outline,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r['student_name'] ?? '-'} (${r['student_code'] ?? ''})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${ltr(r['course_code'] ?? '')} • ${ltr(Format.dateShort(r['session_date']?.toString()))}',
                                style: const TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          StatusChip(
                            status:
                                r['current_status']?.toString() ?? '-',
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward, size: 16),
                          ),
                          StatusChip(
                            status:
                                r['requested_status']?.toString() ?? '-',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('record_n', {'id': ltr(r['attendance_id'] ?? '-')}),
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '“${r['reason'] ?? ''}”',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              foregroundColor: AppColors.error,
                              side: const BorderSide(
                                color: AppColors.error,
                              ),
                            ),
                            onPressed: id == null
                                ? null
                                : () {
                                    final rid = Format.asInt(id);
                                    if (rid != null) {
                                      _decide(rid, 'rejected');
                                    }
                                  },
                            child: Text(tr('reject')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              backgroundColor: AppColors.success,
                            ),
                            onPressed: id == null
                                ? null
                                : () {
                                    final rid = Format.asInt(id);
                                    if (rid != null) {
                                      _decide(rid, 'approved');
                                    }
                                  },
                            child: Text(tr('approve')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
