import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/ui.dart';

/// GET /admin/timetable-slots + POST
/// {section_id, room_id, day_of_week, start_time, end_time}
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;

  static const days = [
    'Saturday',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  @override
  void initState() {
    super.initState();
    _future = _api.getList('/admin/timetable-slots');
  }

  /// Reload that never replaces the screen with an error page:
  /// on failure it keeps the old list and shows a snackbar only.
  Future<void> _reload() async {
    try {
      final fresh = await _api.getList('/admin/timetable-slots');
      if (!mounted) return;
      setState(() => _future = Future.value(fresh));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('cant_load'))),
        );
      }
    }
  }

  Future<void> _create() async {
    final section = TextEditingController();
    final room = TextEditingController();
    final start = TextEditingController(text: '08:00');
    final end = TextEditingController(text: '10:00');
    var day = days[0];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: Text(tr('new_slot')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppField(
                  controller: section,
                  label: tr('nm_section'),
                  helper: tr('h_section_id'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: room,
                  label: 'Room ID',
                  helper: tr('h_room_id'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: day,
                  decoration: InputDecoration(labelText: tr('day')),
                  items: [
                    for (final d in days)
                      DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (v) => setDialog(() => day = v ?? day),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppField(
                        controller: start,
                        label: tr('start'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppField(controller: end, label: tr('end')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('create')),
            ),
          ],
        ),
      ),
    );
    final sid = int.tryParse(section.text.trim());
    final rid = int.tryParse(room.text.trim());
    section.dispose();
    room.dispose();
    start.dispose();
    end.dispose();
    if (ok != true || sid == null || rid == null) return;
    try {
      await _api.postMap(
        '/admin/timetable-slots',
        data: {
          'section_id': sid,
          'room_id': rid,
          'day_of_week': day,
          'start_time': start.text.trim(),
          'end_time': end.text.trim(),
        },
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('created_ok'))),
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
        title: Text(tr('timetable')),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(tr('timetable')),
      ),
      body: FutureBuilder<List<dynamic>>(
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
          final items = (snapshot.data ?? const [])
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
          if (items.isEmpty) return AppEmpty(message: tr('no_slots'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final s = items[i];
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
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            (s['day_of_week']?.toString() ?? '-')
                                .substring(0, 3),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            '#${ltr(s['slot_id'] ?? '-')}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
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
                            '${tr('nm_section')} ${ltr(s['section_id'] ?? '-')} • Room ${ltr(s['room_id'] ?? '-')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${ltr(s['start_time'] ?? '')} – ${ltr(s['end_time'] ?? '')} • ${ltr(s['day_of_week'] ?? '')}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
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
