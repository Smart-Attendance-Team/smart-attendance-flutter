import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';

/// GET /students/my-timetable -> one row per timetable slot of every
/// section the student is actively enrolled in, ordered by weekday
/// then start time.
class StudentSessionsScreen extends StatefulWidget {
  const StudentSessionsScreen({super.key});

  @override
  State<StudentSessionsScreen> createState() => _StudentSessionsScreenState();
}

class _StudentSessionsScreenState extends State<StudentSessionsScreen> {
  final _api = ApiClient();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final list = await _api.getList('/students/my-timetable');
    return list
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  Future<bool> _reload() {
    final future = _load();
    setState(() {
      _future = future;
    });
    return future.then((_) => true).catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('student_sessions')),
        actions: [
          IconButton(
            onPressed: () => refreshWithToast(context, _reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
              onRetry: _reload,
            );
          }
          final slots = snapshot.data ?? const [];
          if (slots.isEmpty) {
            return AppEmpty(message: tr('no_student_sessions'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: slots.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final s = slots[i];
              return AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            trDay(s['day_of_week']?.toString() ?? '-'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            ltr(s['start_time'] ?? ''),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${ltr(s['course_code'] ?? '')} • ${s['course_name'] ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${s['section_name'] ?? ''} • ${s['room_name'] ?? ''}'
                            '${s['building'] != null ? ' • ${s['building']}' : ''}',
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${ltr(s['start_time'] ?? '')} – ${ltr(s['end_time'] ?? '')} • ${trRoomType(s['room_type']?.toString() ?? '')}',
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
              );
            },
          );
        },
      ),
    );
  }
}
