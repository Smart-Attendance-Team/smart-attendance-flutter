import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';

/// GET /admin/rooms + POST {room_name, room_type: lecture|lab}
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _api = ApiClient();
  final _search = TextEditingController();
  late Future<List<dynamic>> _future;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _future = _api.getList('/admin/rooms');
  }

  /// Reload that never replaces the screen with an error page:
  /// on failure it keeps the old list and shows a snackbar only.
  /// Returns true when fresh data arrived (for visible confirmation).
  Future<bool> _reload() async {
    try {
      final fresh = await _api.getList('/admin/rooms');
      if (!mounted) return false;
      setState(() {
        _future = Future.value(fresh);
      });
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('cant_load'))));
      }
      return false;
    }
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final building = TextEditingController();
    final capacity = TextEditingController();
    var type = 'lecture';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: Text(tr('new_room')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppField(controller: name, label: tr('room_name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(labelText: tr('room_type')),
                  items: [
                    DropdownMenuItem(
                      value: 'lecture',
                      child: Text(tr('room_lecture')),
                    ),
                    DropdownMenuItem(value: 'lab', child: Text(tr('room_lab'))),
                  ],
                  onChanged: (v) => setDialog(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                AppField(controller: building, label: tr('building')),
                const SizedBox(height: 12),
                AppField(
                  controller: capacity,
                  label: tr('capacity'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
    final n = name.text.trim();
    final b = building.text.trim();
    final cap = int.tryParse(capacity.text.trim());
    name.dispose();
    building.dispose();
    capacity.dispose();
    if (ok != true || n.isEmpty) return;
    try {
      await _api.postMap(
        '/admin/rooms',
        data: {
          'room_name': n,
          'room_type': type,
          if (b.isNotEmpty) 'building': b,
          if (cap case final cc) 'capacity': cc,
        },
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('created_ok'))));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('cant_load'))));
      }
    }
  }

  Future<void> _edit(Map<String, dynamic> room) async {
    final id = room['room_id'];
    if (id is! num) return;
    final name = TextEditingController(text: '${room['room_name'] ?? ''}');
    final building = TextEditingController(text: '${room['building'] ?? ''}');
    final capacity = TextEditingController(text: '${room['capacity'] ?? ''}');
    var type = '${room['room_type'] ?? 'lecture'}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: Text(tr('edit_room')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppField(controller: name, label: tr('room_name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(labelText: tr('room_type')),
                  items: [
                    DropdownMenuItem(
                      value: 'lecture',
                      child: Text(tr('room_lecture')),
                    ),
                    DropdownMenuItem(value: 'lab', child: Text(tr('room_lab'))),
                  ],
                  onChanged: (v) => setDialog(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                AppField(controller: building, label: tr('building')),
                const SizedBox(height: 12),
                AppField(
                  controller: capacity,
                  label: tr('capacity'),
                  keyboardType: TextInputType.number,
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
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('save')),
            ),
          ],
        ),
      ),
    );
    final n = name.text.trim();
    final b = building.text.trim();
    final cap = int.tryParse(capacity.text.trim());
    name.dispose();
    building.dispose();
    capacity.dispose();
    if (ok != true || n.isEmpty) return;
    try {
      await _api.patchMap(
        '/admin/rooms/${id.toInt()}',
        data: {
          'room_name': n,
          'room_type': type,
          if (b.isNotEmpty) 'building': b,
          if (cap case final value) 'capacity': value,
        },
      );
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('saved_ok'))));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> room) async {
    final id = room['room_id'];
    if (id is! num) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('delete_room')),
        content: Text(tr('delete_confirm_generic')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete('/admin/rooms/${id.toInt()}');
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('deleted_ok'))));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('rooms')),
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
        label: Text(tr('rooms')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: tr('search_hint'),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () => setState(_search.clear),
                      ),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
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
                final q = _search.text.trim().toLowerCase();
                final items = (snapshot.data ?? const [])
                    .whereType<Map>()
                    .map(Map<String, dynamic>.from)
                    .where((r) {
                      if (q.isEmpty) return true;
                      final name = (r['room_name'] ?? '')
                          .toString()
                          .toLowerCase();
                      final building = (r['building'] ?? '')
                          .toString()
                          .toLowerCase();
                      return name.contains(q) || building.contains(q);
                    })
                    .toList();
                if (items.isEmpty) {
                  return AppEmpty(
                    message: (snapshot.data?.isEmpty ?? true)
                        ? tr('no_rooms')
                        : tr('no_results'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = items[i];
                    final isLab = r['room_type'] == 'lab';
                    return AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isLab
                                  ? Icons.science_outlined
                                  : Icons.meeting_room_outlined,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r['room_name']?.toString() ?? '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${trRoomType(r['room_type'])}'
                                  '${r['building'] != null ? ' • ${r['building']}' : ''}'
                                  ' • ${ltr(r['capacity'] ?? '-')}'
                                  ' • ID ${ltr(r['room_id'] ?? '-')}',
                                  style: const TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: tr('edit'),
                            onPressed: () => _edit(r),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            tooltip: tr('delete'),
                            onPressed: () => _delete(r),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
