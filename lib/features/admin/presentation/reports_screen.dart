import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ui.dart';

/// GET /reports/attendance?course_code&section_id&staff_id&student_code&from&to
/// -> {summary, rows[]}
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _api = ApiClient();
  final _course = TextEditingController();
  final _section = TextEditingController();
  final _student = TextEditingController();
  final _staff = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load({});
  }

  @override
  void dispose() {
    _course.dispose();
    _section.dispose();
    _student.dispose();
    _staff.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load(Map<String, dynamic> f) async {
    final res = await _api.get(
      '/reports/attendance',
      queryParameters: f.isEmpty ? null : f,
    );
    return ApiClient.asMap(res.data);
  }

  Map<String, dynamic> _filters() {
    final f = <String, dynamic>{};
    if (_course.text.trim().isNotEmpty) f['course_code'] = _course.text.trim();
    final sec = int.tryParse(_section.text.trim());
    if (sec != null) f['section_id'] = sec;
    if (_student.text.trim().isNotEmpty) {
      f['student_code'] = _student.text.trim();
    }
    final staff = int.tryParse(_staff.text.trim());
    if (staff != null) f['staff_id'] = staff;
    if (_from.text.trim().isNotEmpty) f['from'] = _from.text.trim();
    if (_to.text.trim().isNotEmpty) f['to'] = _to.text.trim();
    return f;
  }

  Future<bool> _apply() {
    final future = _load(_filters());
    setState(() {
      _future = future;
    });
    return future.then((_) => true).catchError((_) => false);
  }

  /// GET /reports/attendance/export?format=csv with the same filters,
  /// saved to a temp file and shared via the system sheet.
  Future<void> _export() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('exporting'))),
    );
    try {
      final csv = await _api.getCsv(
        '/reports/attendance/export',
        queryParameters: {'format': 'csv', ..._filters()},
      );
      if (csv.trim().isEmpty) throw ApiException(tr('no_rows'));
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/attendance-report-${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        text: tr('export_csv'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('exported_ok'))),
        );
      }
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
        title: Text(tr('reports')),
        actions: [
          IconButton(
            tooltip: tr('export_csv'),
            onPressed: _export,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppField(
                        controller: _course,
                        label: tr('course_f'),
                        hint: 'CS101',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppField(
                        controller: _section,
                        label: tr('sec_f'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppField(
                        controller: _student,
                        label: tr('stu_f'),
                        hint: 'S1001',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppField(
                        controller: _staff,
                        label: tr('staff_f'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppField(
                        controller: _from,
                        label: tr('from_f'),
                        hint: '2026-09-01',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppField(
                        controller: _to,
                        label: tr('to_f'),
                        hint: '2026-09-30',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: tr('filter'),
                  icon: Icons.search_rounded,
                  onPressed: () => refreshWithToast(context, _apply),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoading();
                }
                if (snapshot.hasError) {
                  final err = snapshot.error;
                  return AppError(
                    message: err is ApiException
                        ? err.message
                        : tr('cant_load'),
                    onRetry: _apply,
                  );
                }
                final data = snapshot.data ?? const {};
                final summary = ApiClient.asMap(data['summary']);
                final rows = ApiClient.asList(data['rows'])
                    .whereType<Map>()
                    .map(Map<String, dynamic>.from)
                    .toList();
                if (rows.isEmpty) {
                  return AppEmpty(message: tr('no_rows'));
                }
                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: AppColors.headerGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        tr('rep_total', {
                          't': ltr(summary['total'] ?? rows.length),
                          'p': ltr(summary['present'] ?? '-'),
                          'l': ltr(summary['late'] ?? '-'),
                          'e': ltr(summary['excused'] ?? '-'),
                          'a': ltr(summary['absent'] ?? '-'),
                          'r': ltr(summary['attendance_rate_percent'] ?? '-'),
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final r = rows[i];
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
                                        ltr(r['student_name'] ??
                                            r['student_code'] ??
                                            '-'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '${ltr(r['course_name'] ?? r['course_code'] ?? '')} • ${ltr(r['section_name'] ?? '')}',
                                        style: const TextStyle(
                                          color: AppColors.textGrey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '${ltr(r['course_code'] ?? '')} • ${ltr(r['student_code'] ?? '')} • ${ltr(Format.dateShort(r['session_date']?.toString()))}'
                                        '${(r['minutes_late'] is int && (r['minutes_late'] as int) > 0) ? ' • ${ltr(r['minutes_late'])} ${tr('min_unit')}' : ''} • ${trSource(r['source']?.toString() ?? '')}',
                                        style: const TextStyle(
                                          color: AppColors.textGrey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusChip(
                                  status:
                                      r['attendance_status']?.toString() ??
                                      '-',
                                ),
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
          ),
        ],
      ),
    );
  }
}
