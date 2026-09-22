import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/session_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';

/// "My account" page for any role: identity + a role-specific overview.
class ProfileScreen extends StatefulWidget {
  final String userName;
  final String userRole;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.userRole,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _Stat {
  final String label;
  final String value;
  const _Stat(this.label, this.value);
}

class _ProfileData {
  final String email;
  final String? userId;
  final List<_Stat> stats;
  final Map<String, String> extra;
  const _ProfileData({
    required this.email,
    required this.userId,
    required this.stats,
    this.extra = const {},
  });
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiClient();
  late final Future<_ProfileData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProfileData> _load() async {
    final session = await SessionManager.read();
    String? userId;
    try {
      final me = await _api.get('/me');
      if (me.data is Map) {
        userId = (me.data as Map)['userId']?.toString();
      }
    } catch (_) {
      // Identity still shows; stats below may be empty.
    }

    final role = widget.userRole.toLowerCase();
    List<_Stat> stats = const [];
    final extra = <String, String>{};
    try {
      if (role == 'student') {
        try {
          final p = await _api.get('/students/me');
          if (p.data is Map) {
            final m = Map<String, dynamic>.from(p.data as Map);
            if (m['student_code'] != null) {
              extra[tr('student_code_l')] = '${m['student_code']}';
            }
            if (m['level'] != null) extra[tr('level_l')] = '${m['level']}';
            if (m['department_name'] != null) {
              extra[tr('dept_l')] = '${m['department_name']}';
            }
          }
        } catch (_) {}
        final recs = await _api.getList('/attendance/me');
        var present = 0, late = 0, absent = 0;
        for (final raw in recs) {
          if (raw is! Map) continue;
          switch (raw['attendance_status']?.toString()) {
            case 'present':
              present++;
              break;
            case 'late':
              late++;
              break;
            case 'absent':
              absent++;
              break;
          }
        }
        final mine = await _api.getList('/corrections/mine');
        stats = [
          _Stat(tr('all'), '${recs.length}'),
          _Stat(tr('st_present'), '$present'),
          _Stat(tr('st_late'), '$late'),
          _Stat(tr('st_absent'), '$absent'),
          _Stat(tr('my_requests'), '${mine.length}'),
        ];
      } else if (role == 'lecturer' || role == 'ta') {
        try {
          final p = await _api.get('/staff/me');
          if (p.data is Map) {
            final m = Map<String, dynamic>.from(p.data as Map);
            if (m['staff_type'] != null) {
              extra[tr('t_type')] = '${m['staff_type']}';
            }
            if (m['department_name'] != null) {
              extra[tr('dept_l')] = '${m['department_name']}';
            }
          }
        } catch (_) {}
        final pending = await _api.getList('/corrections/pending');
        stats = [_Stat(tr('pending_n'), '${pending.length}')];
      } else if (role == 'admin' || role == 'administrator') {
        final results = await Future.wait([
          _api.getList('/admin/courses'),
          _api.getList('/admin/sections'),
          _api.getList('/admin/rooms'),
          _api.getList('/admin/timetable-slots'),
        ]);
        stats = [
          _Stat(tr('courses'), '${results[0].length}'),
          _Stat(tr('sections'), '${results[1].length}'),
          _Stat(tr('rooms'), '${results[2].length}'),
          _Stat(tr('timetable'), '${results[3].length}'),
        ];
      } else if (role == 'auditor') {
        final logs = await _api.get('/audit-events',
            queryParameters: const {'limit': 1});
        final map = ApiClient.asMap(logs.data);
        var flags = '-';
        try {
          final f = await _api.get('/flags');
          final fm = ApiClient.asMap(f.data);
          flags = '${ApiClient.asList(fm['flags']).length}';
        } catch (_) {}
        stats = [
          _Stat(tr('audit'), '${map['count'] ?? '-'}'),
          _Stat(tr('flags'), flags),
        ];
      }
    } catch (_) {
      // Keep identity visible even if stats fail.
    }

    return _ProfileData(
      email: session?.email ?? '',
      userId: userId,
      stats: stats,
      extra: extra,
    );
  }

  String get _roleLabel {
    switch (widget.userRole.toLowerCase()) {
      case 'lecturer':
      case 'ta':
        return tr('role_lecturer');
      case 'admin':
      case 'administrator':
        return tr('role_admin');
      case 'auditor':
        return tr('role_auditor');
      default:
        return tr('role_student');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('profile'))),
      body: FutureBuilder<_ProfileData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }
          final data = snapshot.data ??
              const _ProfileData(email: '', userId: null, stats: []);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        widget.userName.isEmpty
                            ? 'U'
                            : widget.userName[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.userName,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StatusChip(status: _roleLabel),
                  ],
                ),
              ),
              SectionBar(title: tr('account_info')),
              AppCard(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.alternate_email_rounded),
                      title: Text(tr('email')),
                      subtitle: Text(
                        data.email.isEmpty ? '-' : ltr(data.email),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(tr('f_user_id')),
                      subtitle: Text(data.userId ?? '-'),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.work_outline_rounded),
                      title: Text(tr('f_role')),
                      subtitle: Text(_roleLabel),
                    ),
                    for (final e in data.extra.entries) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.info_outline_rounded),
                        title: Text(e.key),
                        subtitle: Text(ltr(e.value)),
                      ),
                    ],
                  ],
                ),
              ),
              if (data.stats.isNotEmpty) ...[
                SectionBar(title: tr('overview')),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: data.stats.length,
                  itemBuilder: (context, i) {
                    final s = data.stats[i];
                    return AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            s.value,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
