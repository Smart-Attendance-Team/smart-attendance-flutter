import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';

/// GET /admin/departments + POST /admin/departments {department_name}
class DepartmentsScreen extends StatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getList('/admin/departments');
  }

  /// Reload that never replaces the screen with an error page.
  /// Returns true when fresh data arrived (for visible confirmation).
  Future<bool> _reload() async {
    try {
      final fresh = await _api.getList('/admin/departments');
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
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('new_department')),
        content: SingleChildScrollView(
          child: AppField(controller: name, label: tr('dept_name')),
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
    final n = name.text.trim();
    name.dispose();
    if (ok != true || n.isEmpty) return;
    try {
      await _api.postMap(
        '/admin/departments',
        data: {'department_name': n},
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

  Future<void> _edit(Map<String, dynamic> department) async {
    final id = department['department_id'];
    if (id is! num) return;
    final name = TextEditingController(text: '${department['department_name'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('edit_department')),
        content: AppField(controller: name, label: tr('dept_name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('save'))),
        ],
      ),
    );
    final value = name.text.trim();
    name.dispose();
    if (ok != true || value.isEmpty) return;
    try {
      await _api.patchMap('/admin/departments/${id.toInt()}', data: {'department_name': value});
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('saved_ok'))));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Map<String, dynamic> department) async {
    final id = department['department_id'];
    if (id is! num) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('delete_department')),
        content: Text(tr('delete_confirm_generic')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete('/admin/departments/${id.toInt()}');
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
        title: Text(tr('departments')),
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
        label: Text(tr('departments')),
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
            return AppEmpty(message: tr('no_departments'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = items[i];
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
                        Icons.account_balance_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['department_name']?.toString() ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'ID ${ltr(d['department_id'] ?? '-')}',
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.edit_outlined), tooltip: tr('edit'), onPressed: () => _edit(d)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), tooltip: tr('delete'), onPressed: () => _delete(d)),
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
