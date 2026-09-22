import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
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

  static final _timePattern = RegExp(r'^\d{2}:\d{2}$');

  bool _validTime(String v) => _timePattern.hasMatch(v.trim());

  @override
  void initState() {
    super.initState();
    _future = _api.getList('/admin/timetable-slots');
  }

  /// Reload that never replaces the screen with an error page:
  /// on failure it keeps the old list and shows a snackbar only.
  /// Returns true when fresh data arrived (for visible confirmation).
  Future<bool> _reload() async {
    try {
      final fresh = await _api.getList('/admin/timetable-slots');
      if (!mounted) return false;
      setState(() {
        _future = Future.value(fresh);
      });
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('cant_load'))),
        );
      }
      return false;
    }
  }

  Future<void> _create() async {
    // Load pickers from the server so nothing is typed by hand.
    List<Map<String, dynamic>> sections = const [];
    List<Map<String, dynamic>> rooms = const [];
    try {
      final results = await Future.wait([
        _api.getList('/admin/sections'),
        _api.getList('/admin/rooms'),
      ]);
      sections =
          results[0].whereType<Map>().map(Map<String, dynamic>.from).toList();
      rooms =
          results[1].whereType<Map>().map(Map<String, dynamic>.from).toList();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('cant_load'))),
        );
      }
      return;
    }
    if (!mounted) return;

    int? sectionId = sections.isNotEmpty
        ? Format.asInt(sections.first['section_id'])
        : null;
    int? roomId =
        rooms.isNotEmpty ? Format.asInt(rooms.first['room_id']) : null;
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
                DropdownButtonFormField<int>(
                  initialValue: sectionId,
                  decoration: InputDecoration(
                    labelText: tr('pick_section'),
                  ),
                  items: [
                    for (final s in sections)
                      if (Format.asInt(s['section_id']) != null)
                        DropdownMenuItem(
                          value: Format.asInt(s['section_id'])!,
                          child: Text(
                            '${s['section_name'] ?? ''} • ID ${s['section_id']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  ],
                  onChanged: (v) => setDialog(() => sectionId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: roomId,
                  decoration: InputDecoration(
                    labelText: tr('pick_room'),
                  ),
                  items: [
                    for (final r in rooms)
                      if (Format.asInt(r['room_id']) != null)
                        DropdownMenuItem(
                          value: Format.asInt(r['room_id'])!,
                          child: Text(
                            '${r['room_name'] ?? ''} • ID ${r['room_id']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  ],
                  onChanged: (v) => setDialog(() => roomId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: day,
                  decoration: InputDecoration(labelText: tr('day')),
                  items: [
                    for (final d in days)
                      DropdownMenuItem(value: d, child: Text(trDay(d))),
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
    final st = start.text.trim();
    final en = end.text.trim();
    final sid = sectionId;
    final rid = roomId;
    start.dispose();
    end.dispose();
    if (ok != true || sid == null || rid == null) return;
    if (!_validTime(st) || !_validTime(en)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('bad_time'))),
      );
      return;
    }
    try {
      await _api.postMap(
        '/admin/timetable-slots',
        data: {
          'section_id': sid,
          'room_id': rid,
          'day_of_week': day,
          'start_time': st,
          'end_time': en,
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

  /// PATCH /admin/timetable-slots/{id} — send only changed fields.
  Future<void> _editSlot(Map<String, dynamic> s) async {
    final id = s['slot_id'];
    if (id is! num) return;
    List<Map<String, dynamic>> rooms = const [];
    try {
      final list = await _api.getList('/admin/rooms');
      rooms =
          list.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (_) {}
    if (!mounted) return;
    int? roomId = Format.asInt(s['room_id']);
    final fallbackRoom = TextEditingController(text: '${s['room_id'] ?? ''}');
    final start = TextEditingController(
      text: Format.head(s['start_time']?.toString(), 5),
    );
    final end = TextEditingController(
      text: Format.head(s['end_time']?.toString(), 5),
    );
    var day = '${s['day_of_week'] ?? days[0]}';
    if (!days.contains(day)) day = days[0];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: Text(tr('edit_slot')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rooms.isEmpty)
                  AppField(
                    controller: fallbackRoom,
                    label: tr('room_id_l'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (v) =>
                        roomId = int.tryParse(v.trim()),
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue: rooms.any(
                      (r) => Format.asInt(r['room_id']) == roomId,
                    )
                        ? roomId
                        : null,
                    decoration: InputDecoration(
                      labelText: tr('pick_room'),
                    ),
                    items: [
                      for (final r in rooms)
                        if (Format.asInt(r['room_id']) != null)
                          DropdownMenuItem(
                            value: Format.asInt(r['room_id'])!,
                            child: Text(
                              '${r['room_name'] ?? ''} • ID ${r['room_id']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ],
                    onChanged: (v) => setDialog(() => roomId = v),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: day,
                  decoration: InputDecoration(labelText: tr('day')),
                  items: [
                    for (final d in days)
                      DropdownMenuItem(value: d, child: Text(trDay(d))),
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
              child: Text(tr('save')),
            ),
          ],
        ),
      ),
    );
    final rid = roomId;
    final st = start.text.trim();
    final en = end.text.trim();
    fallbackRoom.dispose();
    start.dispose();
    end.dispose();
    if (ok != true) return;
    if (!_validTime(st) || !_validTime(en)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('bad_time'))),
      );
      return;
    }
    try {
      await _api.patchMap(
        '/admin/timetable-slots/${id.toInt()}',
        data: {
          if (rid case final r) 'room_id': r,
          'day_of_week': day,
          'start_time': st,
          'end_time': en,
        },
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

  /// DELETE /admin/timetable-slots/{id} — only slots with no sessions.
  Future<void> _deleteSlot(Map<String, dynamic> s) async {
    final id = s['slot_id'];
    if (id is! num) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('delete_slot')),
        content: Text(tr('delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(100, 44),
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete_slot')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete('/admin/timetable-slots/${id.toInt()}');
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('deleted_ok'))),
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
          IconButton(
            onPressed: () => refreshWithToast(context, _reload),
            icon: const Icon(Icons.refresh),
          ),
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
                            trDay(s['day_of_week']?.toString() ?? '-'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                              fontSize: 12,
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
                            '${tr('nm_section')} ${ltr(s['section_id'] ?? '-')} • ${tr('room')} ${ltr(s['room_id'] ?? '-')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${ltr(s['start_time'] ?? '')} – ${ltr(s['end_time'] ?? '')} • ${ltr(trDay(s['day_of_week'] ?? ''))}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr('edit_slot'),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _editSlot(s),
                    ),
                    IconButton(
                      tooltip: tr('delete_slot'),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppColors.error,
                      ),
                      onPressed: () => _deleteSlot(s),
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
