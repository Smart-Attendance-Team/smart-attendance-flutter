import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ui.dart';

/// Admin directory backed by the real endpoints:
/// GET /admin/students -> AdminStudentListItem[]
/// GET /admin/staff    -> AdminStaffListItem[]
/// Tap a person for every field, edit via
/// PATCH /admin/students/{id} or PATCH /admin/staff/{id}
/// (including activate/deactivate).
class DirectoryScreen extends StatefulWidget {
  final bool students;

  const DirectoryScreen({super.key, required this.students});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _api = ApiClient();
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;

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

  Future<List<Map<String, dynamic>>> _load() async {
    final list = await _api.getList(
      widget.students ? '/admin/students' : '/admin/staff',
    );
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

  String get _idKey => widget.students ? 'student_id' : 'staff_id';
  String get _nameKey => widget.students ? 'student_name' : 'staff_name';

  void _showDetails(Map<String, dynamic> person) {
    final entries = person.entries
        .where((e) => e.value != null && '${e.value}'.isNotEmpty)
        .toList();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(person[_nameKey]?.toString() ?? '-'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                      SelectableText(
                        ltr(_displayValue(e.key, e.value)),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('close')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () {
              Navigator.pop(context);
              _edit(person);
            },
            child: Text(tr('edit')),
          ),
        ],
      ),
    );
  }

  /// Human-friendly rendering for known enum/bool fields.
  String _displayValue(String key, dynamic value) {
    if (value is bool) {
      return value ? tr('active_l') : tr('inactive');
    }
    if (key == 'staff_type' && value is String) {
      return value == 'lecturer' ? tr('role_lecturer') : tr('role_ta');
    }
    if (key == 'room_type' && value is String) {
      return trRoomType(value);
    }
    return '$value';
  }

  Future<void> _edit(Map<String, dynamic> person) async {
    final id = Format.asInt(person[_idKey]);
    if (id == null) return;
    final path = widget.students
        ? '/admin/students/$id'
        : '/admin/staff/$id';

    final name =
        TextEditingController(text: '${person[_nameKey] ?? ''}');
    final level = TextEditingController(text: '${person['level'] ?? ''}');
    final dept = TextEditingController(
      text: '${person['department_id'] ?? ''}',
    );
    var active = person['is_active'] != false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: Text(
            widget.students ? tr('edit_student') : tr('edit_staff'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppField(controller: name, label: tr('f_name')),
                if (widget.students) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: int.tryParse(level.text.trim()),
                    decoration: InputDecoration(
                      labelText: '${tr('level_l')} (${tr('no_change')})',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(tr('no_change')),
                      ),
                      for (var i = 1; i <= 8; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text('$i'),
                        ),
                    ],
                    onChanged: (v) => setDialog(
                      () => level.text = v == null ? '' : '$v',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                AppField(
                  controller: dept,
                  label: tr('dept_id'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    active ? tr('active_l') : tr('inactive'),
                  ),
                  value: active,
                  onChanged: (v) => setDialog(() => active = v),
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
              style:
                  ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('save')),
            ),
          ],
        ),
      ),
    );
    final n = name.text.trim();
    final lvl = int.tryParse(level.text.trim());
    final deptId = int.tryParse(dept.text.trim());
    final wasActive = person['is_active'] != false;
    name.dispose();
    level.dispose();
    dept.dispose();
    if (ok != true) return;
    final data = <String, dynamic>{
      if (n.isNotEmpty) (widget.students ? 'student_name' : 'staff_name'): n,
      if (widget.students && lvl != null) 'level': lvl,
      if (deptId case final d) 'department_id': d,
      if (active != wasActive) 'is_active': active,
    };
    if (data.isEmpty) return;
    try {
      await _api.patchMap(path, data: data);
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
        title: Text(
          widget.students ? tr('students') : tr('lecturers'),
        ),
        actions: [
          IconButton(
            onPressed: () => refreshWithToast(context, _reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
            child: FutureBuilder<List<Map<String, dynamic>>>(
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
                final rows = (snapshot.data ?? const []).where((p) {
                  if (q.isEmpty) return true;
                  final name =
                      (p[_nameKey] ?? '').toString().toLowerCase();
                  final code = widget.students
                      ? (p['student_code'] ?? '').toString().toLowerCase()
                      : (p['email'] ?? '').toString().toLowerCase();
                  final id =
                      (p[_idKey] ?? '').toString().toLowerCase();
                  return name.contains(q) ||
                      code.contains(q) ||
                      id.contains(q);
                }).toList();
                if (rows.isEmpty) {
                  return AppEmpty(
                    message: widget.students
                        ? tr('no_students')
                        : tr('no_staff'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = rows[i];
                    final active = p['is_active'] != false;
                    final sub = widget.students
                        ? p['student_code']?.toString()
                        : p['staff_type']?.toString() == 'lecturer'
                            ? tr('role_lecturer')
                            : tr('role_ta');
                    return AppCard(
                      padding: const EdgeInsets.all(6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: active
                              ? AppColors.primaryLight
                              : Colors.grey.shade300,
                          child: Icon(
                            widget.students
                                ? Icons.school_outlined
                                : Icons.person_outline,
                            color: active
                                ? AppColors.primaryDark
                                : Colors.grey,
                          ),
                        ),
                        title: Text(
                          p[_nameKey]?.toString() ?? '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'ID ${ltr(p[_idKey] ?? '-')} • ${ltr(sub ?? '')}'
                          '${widget.students && p['level'] != null ? ' • ${tr('level_l')} ${ltr(p['level'])}' : ''}'
                          '${active ? '' : ' • ${tr('inactive')}'}',
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 12,
                          ),
                        ),
                        trailing:
                            const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showDetails(p),
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
