import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ui.dart';

/// GET /sessions/{id}/roster -> {session_status, summary, students[]}
/// PATCH /sessions/{id}/attendance/{attendanceId} {status, reason}
class LiveRosterScreen extends StatefulWidget {
  final String sessionId;
  const LiveRosterScreen({super.key, required this.sessionId});

  @override
  State<LiveRosterScreen> createState() => _LiveRosterScreenState();
}

class _LiveRosterScreenState extends State<LiveRosterScreen> {
  final _api = ApiClient();
  final _search = TextEditingController();
  late Future<Map<String, dynamic>> _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final res = await _api.get('/sessions/${widget.sessionId}/roster');
    return ApiClient.asMap(res.data);
  }

  void _reload() {
    setState(() {
      _filter = 'all';
      _future = _load();
    });
  }

  Future<void> _fix(int attendanceId, String current) async {
    var status = current == 'present' ? 'absent' : 'present';
    final reason = TextEditingController();
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: Text(tr('fix_title', {'id': ltr(attendanceId)})),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              DropdownButtonFormField<String>(
                initialValue: status,
                items: [
                  DropdownMenuItem(
                    value: 'present',
                    child: Text(tr('st_present')),
                  ),
                  DropdownMenuItem(
                    value: 'absent',
                    child: Text(tr('st_absent')),
                  ),
                  DropdownMenuItem(
                    value: 'excused',
                    child: Text(tr('st_excused')),
                  ),
                ],
                onChanged: (v) => setDialog(() => status = v ?? status),
              ),
              const SizedBox(height: 12),
              AppField(
                controller: reason,
                label: tr('reason_min'),
              ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 44),
              ),
              onPressed: () => Navigator.pop(context, {
                'status': status,
                'reason': reason.text.trim(),
              }),
              child: Text(tr('save')),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    if (data == null || (data['reason'] ?? '').length < 3) {
      if (data != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('reason_need3'))),
        );
      }
      return;
    }
    try {
      await _api.patchMap(
        '/sessions/${widget.sessionId}/attendance/$attendanceId',
        data: data,
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('saved_ok'))),
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
        title: Text('${tr('roster')} ${ltr(widget.sessionId)}'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AppLoading(message: tr('roster_loading'));
          }
          if (snapshot.hasError) {
            final err = snapshot.error;
            final code = err is ApiException ? err.statusCode : null;
            return AppError(
              message: err is ApiException
                  ? err.message
                  : tr('cant_load'),
              hint: (code == 404 || code == 403) ? tr('roster_hint') : null,
              onRetry: _reload,
            );
          }
          final data = snapshot.data ?? const {};
          final summary = ApiClient.asMap(data['summary']);
          final all = ApiClient.asList(data['students'])
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();

          final total = (summary['total'] is int)
              ? summary['total'] as int
              : all.length;
          final absent = (summary['absent'] is int)
              ? summary['absent'] as int
              : all
                  .where((s) =>
                      s['attendance_status']?.toString() == 'absent')
                  .length;
          final absentPct =
              total == 0 ? 0 : ((absent * 100) / total).round();

          final counts = <String, int>{};
          for (final s in all) {
            final st = (s['attendance_status'] ?? '-').toString();
            counts[st] = (counts[st] ?? 0) + 1;
          }

          final q = _search.text.trim().toLowerCase();
          final visible = all.where((s) {
            if (_filter != 'all' &&
                (s['attendance_status'] ?? '').toString() != _filter) {
              return false;
            }
            if (q.isEmpty) return true;
            final name =
                (s['student_name'] ?? '').toString().toLowerCase();
            final code =
                (s['student_code'] ?? '').toString().toLowerCase();
            return name.contains(q) || code.contains(q);
          }).toList();

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.headerGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          trStatus(
                            (data['session_status'] ?? '-').toString(),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tr('abs_rate', {'p': ltr(absentPct)}),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _count(
                          '${summary['present'] ?? 0}',
                          tr('st_present'),
                        ),
                        _count('${summary['late'] ?? 0}', tr('st_late')),
                        _count(
                          '${summary['excused'] ?? 0}',
                          tr('st_excused'),
                        ),
                        _count(
                          '${summary['absent'] ?? 0}',
                          tr('st_absent'),
                        ),
                        _count(
                          '${summary['total'] ?? all.length}',
                          tr('all'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: tr('search_roster'),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: q.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () => setState(_search.clear),
                          ),
                    isDense: true,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Row(
                  children: [
                    _chip('all', '${tr('all')} (${all.length})'),
                    for (final e in counts.entries)
                      _chip(
                        e.key,
                        '${trStatus(e.key)} (${e.value})',
                      ),
                  ],
                ),
              ),
              Expanded(
                child: all.isEmpty
                    ? AppEmpty(message: tr('no_roster'))
                    : visible.isEmpty
                        ? AppEmpty(message: tr('no_filter'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final s = visible[i];
                          final st =
                              s['attendance_status']?.toString() ?? '-';
                          final late = s['minutes_late'];
                          return AppCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryLight,
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                s['student_name']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                '${ltr(s['student_code'] ?? '')}'
                                '${late is int && late > 0 ? ' • ${ltr(late)}' : ''}'
                                ' • ${ltr(s['source'] ?? '')}'
                                ' • ${ltr(Format.time(s['attendance_timestamp']?.toString()))}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StatusChip(status: st),
                                  IconButton(
                                    tooltip: tr('fix_title', {'id': ''}).trim(),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                    ),
                                    onPressed: s['attendance_id'] is int
                                        ? () => _fix(
                                            s['attendance_id'] as int,
                                            st,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
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
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _count(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
