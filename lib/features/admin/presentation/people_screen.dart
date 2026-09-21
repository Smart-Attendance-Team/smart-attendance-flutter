import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/ui.dart';

/// POST /admin/students {email, password, student_code, student_name, ...}
/// POST /admin/staff {email, password, staff_name, staff_type, ...}
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _api = ApiClient();

  final _sEmail = TextEditingController();
  final _sPass = TextEditingController();
  final _sCode = TextEditingController();
  final _sName = TextEditingController();

  final _tEmail = TextEditingController();
  final _tPass = TextEditingController();
  final _tName = TextEditingController();
  var _tType = 'lecturer';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _sEmail.dispose();
    _sPass.dispose();
    _sCode.dispose();
    _sName.dispose();
    _tEmail.dispose();
    _tPass.dispose();
    _tName.dispose();
    super.dispose();
  }

  Future<void> _createStudent() async {
    if (_sEmail.text.trim().isEmpty ||
        _sPass.text.length < 8 ||
        _sCode.text.trim().isEmpty ||
        _sName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('fill_all'))),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final created = await _api.postMap(
        '/admin/students',
        data: {
          'email': _sEmail.text.trim(),
          'password': _sPass.text,
          'student_code': _sCode.text.trim(),
          'student_name': _sName.text.trim(),
        },
      );
      if (!mounted) return;
      _sEmail.clear();
      _sPass.clear();
      _sCode.clear();
      _sName.clear();
      _showIds(
        'Student created',
        {'student_id': created['student_id'], 'user_id': created['user_id']},
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createStaff() async {
    if (_tEmail.text.trim().isEmpty ||
        _tPass.text.length < 8 ||
        _tName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('fill_all'))),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final created = await _api.postMap(
        '/admin/staff',
        data: {
          'email': _tEmail.text.trim(),
          'password': _tPass.text,
          'staff_name': _tName.text.trim(),
          'staff_type': _tType,
        },
      );
      if (!mounted) return;
      _tEmail.clear();
      _tPass.clear();
      _tName.clear();
      _showIds(
        'Staff created',
        {'staff_id': created['staff_id'], 'user_id': created['user_id']},
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Shows the IDs returned by the backend so they can be used
  /// for enrollment / staff assignment (there is no list endpoint).
  void _showIds(String title, Map<String, dynamic> ids) {
    final lines = ids.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('save_ids_hint')),
              const SizedBox(height: 8),
              SelectableText(
                lines.isEmpty ? '-' : ltr(lines),
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('people')),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              text: tr('tab_student'),
              icon: const Icon(Icons.school_outlined, size: 20),
            ),
            Tab(
              text: tr('tab_staff'),
              icon: const Icon(Icons.person_outline, size: 20),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppField(
                    controller: _sName,
                    label: tr('s_name'),
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    controller: _sCode,
                    label: tr('s_code'),
                    prefixIcon: Icons.tag_rounded,
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    controller: _sEmail,
                    label: tr('email'),
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    controller: _sPass,
                    label: tr('s_pass'),
                    obscure: true,
                    prefixIcon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  AppButton(
                    label: tr('create_student'),
                    icon: Icons.person_add_alt_rounded,
                    loading: _busy,
                    onPressed: _createStudent,
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppField(
                    controller: _tName,
                    label: tr('t_name'),
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _tType,
                    decoration: InputDecoration(labelText: tr('t_type')),
                    items: [
                      DropdownMenuItem(
                        value: 'lecturer',
                        child: Text(tr('role_lecturer')),
                      ),
                      const DropdownMenuItem(
                        value: 'TA',
                        child: Text('TA'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _tType = v ?? 'lecturer'),
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    controller: _tEmail,
                    label: tr('email'),
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    controller: _tPass,
                    label: tr('s_pass'),
                    obscure: true,
                    prefixIcon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  AppButton(
                    label: tr('create_staff'),
                    icon: Icons.person_add_alt_rounded,
                    loading: _busy,
                    onPressed: _createStaff,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
