import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ui.dart';

/// GET /admin/sections + POST {course_id, section_name, semester}
class SectionsScreen extends StatefulWidget {
  const SectionsScreen({super.key});

  @override
  State<SectionsScreen> createState() => _SectionsScreenState();
}

class _SectionsScreenState extends State<SectionsScreen> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getList('/admin/sections');
  }

  /// Reload that never replaces the screen with an error page:
  /// on failure it keeps the old list and shows a snackbar only.
  /// Returns true when fresh data arrived (for visible confirmation).
  Future<bool> _reload() async {
    try {
      final fresh = await _api.getList('/admin/sections');
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
    final courseId = TextEditingController();
    final name = TextEditingController();
    final semester = TextEditingController();
    final capacity = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('new_section')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            AppField(
              controller: courseId,
              label: '${tr('course_f')} ID',
              helper: tr('h_course_id'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            AppField(controller: name, label: tr('sec_name')),
            const SizedBox(height: 12),
            AppField(controller: semester, label: tr('semester')),
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
    );
    final cid = int.tryParse(courseId.text.trim());
    final n = name.text.trim();
    final s = semester.text.trim();
    final cap = int.tryParse(capacity.text.trim());
    courseId.dispose();
    name.dispose();
    semester.dispose();
    capacity.dispose();
    if (ok != true || cid == null || n.isEmpty || s.isEmpty) return;
    try {
      await _api.postMap(
        '/admin/sections',
        data: {
          'course_id': cid,
          'section_name': n,
          'semester': s,
          if (cap case final cc) 'capacity': cc,
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

  Future<void> _edit(Map<String, dynamic> section) async {
    final id = section['section_id'];
    if (id is! num) return;
    final name = TextEditingController(text: '${section['section_name'] ?? ''}');
    final semester = TextEditingController(text: '${section['semester'] ?? ''}');
    final capacity = TextEditingController(text: '${section['capacity'] ?? ''}');
    List<Map<String, dynamic>> courses = const [];
    try {
      final list = await _api.getList('/admin/courses');
      courses =
          list.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (_) {}
    if (!mounted) return;
    int? courseId = Format.asInt(section['course_id']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: Text(tr('edit_section')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (courses.isNotEmpty)
                  DropdownButtonFormField<int?>(
                    key: ValueKey<int?>(courseId),
                    initialValue: courses.any(
                      (c) => Format.asInt(c['course_id']) == courseId,
                    )
                        ? courseId
                        : null,
                    decoration: InputDecoration(labelText: tr('course_f')),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(tr('no_change')),
                      ),
                      for (final c in courses)
                        if (Format.asInt(c['course_id']) != null)
                          DropdownMenuItem(
                            value: Format.asInt(c['course_id']),
                            child: Text(
                              '${c['course_code'] ?? ''} • ${c['course_name'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ],
                    onChanged: (v) => setDialog(() => courseId = v),
                  ),
                if (courses.isNotEmpty) const SizedBox(height: 12),
                AppField(controller: name, label: tr('sec_name')),
                const SizedBox(height: 12),
                AppField(controller: semester, label: tr('semester')),
                const SizedBox(height: 12),
                AppField(controller: capacity, label: tr('capacity'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'))),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('save'))),
          ],
        ),
      ),
    );
    final n = name.text.trim();
    final s = semester.text.trim();
    final cap = int.tryParse(capacity.text.trim());
    name.dispose();
    semester.dispose();
    capacity.dispose();
    if (ok != true || n.isEmpty || s.isEmpty) return;
    try {
      await _api.patchMap('/admin/sections/${id.toInt()}', data: {
        if (courseId case final c) 'course_id': c,
        'section_name': n,
        'semester': s,
        if (cap case final value) 'capacity': value,
      });
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('saved_ok'))));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Map<String, dynamic> section) async {
    final id = section['section_id'];
    if (id is! num) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('delete_section')),
        content: Text(tr('delete_confirm_generic')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete('/admin/sections/${id.toInt()}');
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('deleted_ok'))));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('sections')),
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
        label: Text(tr('sections')),
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
          if (items.isEmpty) {
            return AppEmpty(message: tr('no_sections'));
          }
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.group_work_outlined,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['section_name']?.toString() ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'ID ${ltr(s['section_id'] ?? '-')} • ${tr('course_l')} ${ltr(s['course_id'] ?? '-')} • ${ltr(s['semester'] ?? '')}',
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.edit_outlined), tooltip: tr('edit'), onPressed: () => _edit(s)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), tooltip: tr('delete'), onPressed: () => _delete(s)),
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
