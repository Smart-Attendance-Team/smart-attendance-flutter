import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ui.dart';

/// GET /admin/courses + POST /admin/courses {course_code, course_name}
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
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
    _future = _api.getList('/admin/courses');
  }

  /// Reload that never replaces the screen with an error page:
  /// on failure it keeps the old list and shows a snackbar only.
  /// Returns true when fresh data arrived (for visible confirmation).
  Future<bool> _reload() async {
    try {
      final fresh = await _api.getList('/admin/courses');
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
    final code = TextEditingController();
    final name = TextEditingController();
    final dept = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('new_course')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppField(controller: code, label: tr('code_ex')),
              const SizedBox(height: 12),
              AppField(controller: name, label: tr('course_name')),
              const SizedBox(height: 12),
              AppField(
                controller: dept,
                label: tr('dept_id'),
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
    final c = code.text.trim();
    final n = name.text.trim();
    final deptId = int.tryParse(dept.text.trim());
    code.dispose();
    name.dispose();
    dept.dispose();
    if (ok != true || c.isEmpty || n.isEmpty) return;
    try {
      await _api.postMap(
        '/admin/courses',
        data: {
          'course_code': c,
          'course_name': n,
          if (deptId case final d) 'department_id': d,
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

  Future<void> _edit(Map<String, dynamic> course) async {
    final id = course['course_id'];
    if (id is! num) return;
    final code = TextEditingController(text: '${course['course_code'] ?? ''}');
    final name = TextEditingController(text: '${course['course_name'] ?? ''}');
    List<Map<String, dynamic>> departments = const [];
    try {
      final list = await _api.getList('/admin/departments');
      departments =
          list.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (_) {}
    if (!mounted) return;
    int? deptId = Format.asInt(course['department_id']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: Text(tr('edit_course')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppField(controller: code, label: tr('code_ex')),
                const SizedBox(height: 12),
                AppField(controller: name, label: tr('course_name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  key: ValueKey<int?>(deptId),
                  initialValue: deptId,
                  decoration: InputDecoration(labelText: tr('dept_pick')),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(tr('no_change')),
                    ),
                    for (final d in departments)
                      if (Format.asInt(d['department_id']) != null)
                        DropdownMenuItem(
                          value: Format.asInt(d['department_id']),
                          child: Text(
                            '${d['department_name'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  ],
                  onChanged: (v) => setDialog(() => deptId = v),
                ),
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
    final c = code.text.trim();
    final n = name.text.trim();
    code.dispose();
    name.dispose();
    if (ok != true || c.isEmpty || n.isEmpty) return;
    try {
      await _api.patchMap('/admin/courses/${id.toInt()}', data: {
        'course_code': c,
        'course_name': n,
        if (deptId case final d) 'department_id': d,
      });
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('saved_ok'))));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Map<String, dynamic> course) async {
    final id = course['course_id'];
    if (id is! num) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('delete_course')),
        content: Text(tr('delete_confirm_generic')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete('/admin/courses/${id.toInt()}');
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
        title: Text(tr('courses')),
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
        label: Text(tr('courses')),
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
              .where((c) {
                if (q.isEmpty) return true;
                final name =
                    (c['course_name'] ?? '').toString().toLowerCase();
                final code =
                    (c['course_code'] ?? '').toString().toLowerCase();
                return name.contains(q) || code.contains(q);
              })
              .toList();
          if (items.isEmpty) {
            return AppEmpty(
              message: (snapshot.data?.isEmpty ?? true)
                  ? tr('no_courses')
                  : tr('no_results'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = items[i];
              return AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['course_name']?.toString() ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${ltr(c['course_code'] ?? '')} • ID ${ltr(c['course_id'] ?? '-')}',
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.edit_outlined), tooltip: tr('edit'), onPressed: () => _edit(c)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), tooltip: tr('delete'), onPressed: () => _delete(c)),
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
