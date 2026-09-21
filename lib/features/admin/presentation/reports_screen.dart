import 'package:flutter/material.dart';

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
    super.dispose();
  }

  Future<Map<String, dynamic>> _load(Map<String, dynamic> f) async {
    final res = await _api.get(
      '/reports/attendance',
      queryParameters: f.isEmpty ? null : f,
    );
    return ApiClient.asMap(res.data);
  }

  void _apply() {
    final f = <String, dynamic>{};
    if (_course.text.trim().isNotEmpty) f['course_code'] = _course.text.trim();
    final sec = int.tryParse(_section.text.trim());
    if (sec != null) f['section_id'] = sec;
    if (_student.text.trim().isNotEmpty) {
      f['student_code'] = _student.text.trim();
    }
    setState(() => _future = _load(f));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('reports'))),
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
                    SizedBox(
                      width: 120,
                      child: AppButton(
                        label: tr('filter'),
                        icon: Icons.search_rounded,
                        onPressed: _apply,
                      ),
                    ),
                  ],
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
                                        '${r['student_name'] ?? r['student_code'] ?? '-'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '${ltr(r['course_code'] ?? '')} • ${ltr(Format.dateShort(r['session_date']?.toString()))} • ${ltr(r['source'] ?? '')}',
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
