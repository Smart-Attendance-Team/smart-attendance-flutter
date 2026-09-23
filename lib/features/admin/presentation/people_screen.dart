import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/format.dart';
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
  final _sLevel = TextEditingController();
  final _sDept = TextEditingController();

  final _tEmail = TextEditingController();
  final _tPass = TextEditingController();
  final _tName = TextEditingController();
  final _tDept = TextEditingController();
  var _tType = 'lecturer';

  // Simple CSV file import (POST /admin/imports/students, text/csv).
  final _csvPass = TextEditingController();
  String? _csvName;
  String? _csvText;
  int? _csvSectionId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _sEmail.dispose();
    _sPass.dispose();
    _sCode.dispose();
    _sName.dispose();
    _sLevel.dispose();
    _sDept.dispose();
    _tEmail.dispose();
    _tPass.dispose();
    _tName.dispose();
    _tDept.dispose();
    _csvPass.dispose();
    super.dispose();
  }

  Future<void> _createStudent() async {
    if (_sEmail.text.trim().isEmpty ||
        _sPass.text.length < 8 ||
        _sCode.text.trim().isEmpty ||
        _sName.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('fill_all'))));
      return;
    }
    setState(() => _busy = true);
    try {
      final level = int.tryParse(_sLevel.text.trim());
      final dept = int.tryParse(_sDept.text.trim());
      final created = await _api.postMap(
        '/admin/students',
        data: {
          'email': _sEmail.text.trim(),
          'password': _sPass.text,
          'student_code': _sCode.text.trim(),
          'student_name': _sName.text.trim(),
          if (level case final l) 'level': l,
          if (dept case final d) 'department_id': d,
        },
      );
      if (!mounted) return;
      _sEmail.clear();
      _sPass.clear();
      _sCode.clear();
      _sName.clear();
      _sLevel.clear();
      _sDept.clear();
      _showIds(tr('student_created'), {
        'student_id': created['student_id'],
        'user_id': created['user_id'],
      });
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createStaff() async {
    if (_tEmail.text.trim().isEmpty ||
        _tPass.text.length < 8 ||
        _tName.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('fill_all'))));
      return;
    }
    setState(() => _busy = true);
    try {
      final dept = int.tryParse(_tDept.text.trim());
      final created = await _api.postMap(
        '/admin/staff',
        data: {
          'email': _tEmail.text.trim(),
          'password': _tPass.text,
          'staff_name': _tName.text.trim(),
          'staff_type': _tType,
          if (dept case final d) 'department_id': d,
        },
      );
      if (!mounted) return;
      _tEmail.clear();
      _tPass.clear();
      _tName.clear();
      _tDept.clear();
      _showIds(tr('staff_created'), {
        'staff_id': created['staff_id'],
        'user_id': created['user_id'],
      });
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
            child: Text(tr('done')),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCsvFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'txt'],
        withData: true,
      );
      final file = result?.files.single;
      if (file == null) return;
      String? text = file.bytes != null
          ? utf8.decode(file.bytes!, allowMalformed: true)
          : null;
      if (text == null && file.path != null) {
        text = await File(file.path!).readAsString();
      }
      if (!mounted) return;
      setState(() {
        _csvName = file.name;
        _csvText = text?.trim().isEmpty == true ? null : text?.trim();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('cant_load'))),
        );
      }
    }
  }

  int _csvRowCount() {
    final text = _csvText;
    if (text == null || text.isEmpty) return 0;
    final lines = text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return 0;
    final first = lines.first.toLowerCase();
    final hasHeader = first.contains('student_code') ||
        first.contains('email') ||
        first.contains('student_name');
    return hasHeader ? lines.length - 1 : lines.length;
  }

  Future<void> _uploadCsv() async {
    final pass = _csvPass.text;
    final csv = _csvText;
    if (csv == null || csv.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('pick_file'))));
      return;
    }
    if (pass.length < 8) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('csv_pass'))));
      return;
    }
    final query = <String, dynamic>{'default_password': pass};
    if (_csvSectionId != null) query['section_id'] = _csvSectionId;
    setState(() => _busy = true);
    try {
      final res = await _api.postCsv(
        '/admin/imports/students',
        csv,
        queryParameters: query,
      );
      if (!mounted) return;
      final rejected = ApiClient.asList(
        res['rejected_rows'],
      ).whereType<Map>().map(Map<String, dynamic>.from).toList();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('import_title')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('import_summary', {
                    'c': '${res['created'] ?? '-'}',
                    't': '${res['total'] ?? '-'}',
                    'r': '${res['rejected'] ?? '-'}',
                  }),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (rejected.isEmpty)
                  Text(tr('no_rejected'))
                else
                  for (final row in rejected)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Row ${row['row'] ?? '?'}: ${row['reason'] ?? ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
              onPressed: () => Navigator.pop(context),
              child: Text(tr('done')),
            ),
          ],
        ),
      );
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            Tab(
              text: tr('tab_csv'),
              icon: const Icon(Icons.upload_file_outlined, size: 20),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppField(
                          controller: _sLevel,
                          label: tr('level18'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppField(
                          controller: _sDept,
                          label: tr('dept_id'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
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
                      DropdownMenuItem(value: 'TA', child: Text(tr('role_ta'))),
                    ],
                    onChanged: (v) => setState(() => _tType = v ?? 'lecturer'),
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
                  const SizedBox(height: 12),
                  AppField(
                    controller: _tDept,
                    label: tr('dept_id'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('csv_hint'),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickCsvFile,
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(
                      _csvName ?? tr('pick_file'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_csvName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      tr('file_rows', {'n': '${_csvRowCount()}'}),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  AppField(
                    controller: _csvPass,
                    label: tr('csv_pass'),
                    obscure: true,
                    prefixIcon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  _CsvSectionPicker(
                    api: _api,
                    value: _csvSectionId,
                    onChanged: (v) =>
                        setState(() => _csvSectionId = v),
                  ),
                  const SizedBox(height: 14),
                  AppButton(
                    label: tr('import_btn'),
                    icon: Icons.upload_file_outlined,
                    loading: _busy,
                    onPressed: _uploadCsv,
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

/// Section dropdown for the CSV import, loaded from GET /admin/sections.
/// Null = no enrollment, students are only created.
class _CsvSectionPicker extends StatefulWidget {
  final ApiClient api;
  final int? value;
  final ValueChanged<int?> onChanged;

  const _CsvSectionPicker({
    required this.api,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_CsvSectionPicker> createState() => _CsvSectionPickerState();
}

class _CsvSectionPickerState extends State<_CsvSectionPicker> {
  late final Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getList('/admin/sections').then(
          (list) => list
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final sections = snapshot.data ?? const [];
        return DropdownButtonFormField<int?>(
          key: ValueKey<int?>(widget.value),
          initialValue: widget.value,
          decoration: InputDecoration(labelText: tr('pick_section')),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(tr('no_enroll')),
            ),
            for (final s in sections)
              if (Format.asInt(s['section_id']) != null)
                DropdownMenuItem(
                  value: Format.asInt(s['section_id']),
                  child: Text(
                    '${s['section_name'] ?? ''} • ID ${s['section_id']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
          ],
          onChanged: widget.onChanged,
        );
      },
    );
  }
}
