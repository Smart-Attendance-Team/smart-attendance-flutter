import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ui.dart';

/// GET /attendance/me -> MyAttendanceRecord[]
class MyAttendanceScreen extends StatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _api.getList('/attendance/me');
  }

  /// Manual refresh: returns true when fresh data arrived, so the
  /// caller can confirm visibly. Auto reloads call the loader directly.
  Future<bool> _reload() {
    final future = _api.getList('/attendance/me');
    setState(() {
      _future = future;
    });
    return future.then((_) => true).catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('my_att')),
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
            return AppLoading(message: tr('loading_records'));
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
          final all = (snapshot.data ?? const [])
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
          if (all.isEmpty) return AppEmpty(message: tr('no_records'));

          final counts = <String, int>{};
          for (final r in all) {
            final s = (r['attendance_status'] ?? '-').toString();
            counts[s] = (counts[s] ?? 0) + 1;
          }
          final visible = _filter == 'all'
              ? all
              : all
                    .where(
                      (r) =>
                          (r['attendance_status'] ?? '').toString() == _filter,
                    )
                    .toList();

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _chip('all', '${tr('all')} (${all.length})'),
                    for (final e in counts.entries)
                      _chip(e.key, '${trStatus(e.key)} (${e.value})'),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? AppEmpty(message: tr('no_filter'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final r = visible[i];
                          final status =
                              r['attendance_status']?.toString() ?? '-';
                          final late = r['minutes_late'];
                          return AppCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${ltr(r['course_code'] ?? '')} • ${ltr(r['course_name'] ?? tr('course_unknown'))}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${ltr(Format.dateShort(r['session_date']?.toString()))}'
                                        '${late is int && late > 0 ? ' • ${ltr(late)} ${tr('min_unit')}' : ''}'
                                        ' • #${ltr(r['attendance_id'] ?? '-')}',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusChip(status: status),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}
