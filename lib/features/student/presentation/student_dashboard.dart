import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/my_id_card.dart';
import '../../../core/widgets/ui.dart';
import '../../attendance/presentation/check_in_sheet.dart';
import 'correction_request_screen.dart';
import 'my_attendance_screen.dart';

class StudentDashboard extends StatelessWidget {
  final String userName;
  const StudentDashboard({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(userName: userName, userRole: 'student'),
      body: Column(
        children: [
          DashboardHeader(
            name: userName,
            roleLabel: tr('role_student'),
            subtitle: tr('stu_sub'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('mark_att'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  tr('mark_sub'),
                                  style: const TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: tr('scan_qr'),
                        icon: Icons.qr_code_scanner_rounded,
                        onPressed: () => showCheckIn(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _StudentOverview(),
                const SizedBox(height: 12),
                MyIdCard(
                  metaKey: 'student_id',
                  metaLabel: tr('student_id_l'),
                  extraMetaKey: 'student_code',
                  extraMetaLabel: tr('student_code_l'),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.fact_check_outlined,
                  color: AppColors.accent,
                  title: tr('my_att'),
                  subtitle: tr('my_att_sub'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyAttendanceScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.edit_note_rounded,
                  color: AppColors.warning,
                  title: tr('corr'),
                  subtitle: tr('corr_sub'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CorrectionRequestScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Overview built from GET /attendance/me: how many subjects the student
/// is recorded in, how many sessions, and the per-subject breakdown.
/// NOTE: the backend exposes no "upcoming sessions" endpoint, so only
/// attended sessions can be shown.
class _StudentOverview extends StatefulWidget {
  const _StudentOverview();

  @override
  State<_StudentOverview> createState() => _StudentOverviewState();
}

class _StudentOverviewState extends State<_StudentOverview> {
  late final Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient().getList('/attendance/me').then(
          (list) => list
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final recs = snapshot.data ?? const <Map<String, dynamic>>[];
        final byCourse = <String, Map<String, String>>{};
        for (final r in recs) {
          final code = r['course_code']?.toString() ?? '-';
          byCourse.putIfAbsent(
            code,
            () => {
              'name': r['course_name']?.toString() ?? '',
              'count': '0',
            },
          );
          byCourse[code]!['count'] =
              '${int.parse(byCourse[code]!['count']!) + 1}';
        }
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _miniStat('${byCourse.length}', tr('my_subjects')),
                  _miniStat('${recs.length}', tr('sessions_n')),
                ],
              ),
              if (byCourse.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                for (final e in byCourse.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.value['name']!.isEmpty
                                ? e.key
                                : '${e.key} • ${e.value['name']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        StatusChip(
                          status:
                              '${e.value['count']} ${tr('sessions_n')}',
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Text(
                tr('upcoming_na'),
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
