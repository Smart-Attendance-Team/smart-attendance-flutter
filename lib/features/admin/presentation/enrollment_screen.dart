import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ui.dart';

/// POST /admin/enrollments {student_id: int, section_id: int}
/// POST /admin/sections/{sectionId}/staff {staff_id, staff_role}
class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  final _api = ApiClient();
  late Future<_EnrollData> _dataFuture;
  late Future<List<dynamic>> _enrollmentsFuture;
  var _staffRole = 'lecturer';
  bool _busy = false;

  // Pickers (null = not chosen yet). -1 means "type the ID by hand".
  int? _studentId;
  int? _sectionId;
  int? _staffId;
  int? _staffSectionId;
  final _studentManual = TextEditingController();
  final _staffManual = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
    _enrollmentsFuture = _api.getList('/admin/enrollments');
  }

  Future<_EnrollData> _load() async {
    final results = await Future.wait([
      _api.getList('/admin/sections'),
      _api.getList('/admin/students'),
      _api.getList('/admin/staff'),
    ]);
    List<Map<String, dynamic>> toMaps(List<dynamic> list) =>
        list.whereType<Map>().map(Map<String, dynamic>.from).toList();
    return _EnrollData(
      sections: toMaps(results[0]),
      students: toMaps(results[1]),
      staff: toMaps(results[2]),
    );
  }

  Future<bool> _reload() {
    final data = _load();
    final enrollments = _api.getList('/admin/enrollments');
    setState(() {
      _dataFuture = data;
      _enrollmentsFuture = enrollments;
    });
    return Future.wait([data, enrollments])
        .then((_) => true)
        .catchError((_) => false);
  }

  Future<void> _unenroll(Map<String, dynamic> e) async {
    final id = Format.asInt(e['enrollment_id']);
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('unenroll')),
        content: Text(tr('unenroll_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('unenroll')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete('/admin/enrollments/$id');
      if (!mounted) return;
      setState(() {
        _enrollmentsFuture = _api.getList('/admin/enrollments');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('deleted_ok'))),
      );
    } on ApiException catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ex.message)));
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
  void dispose() {
    _studentManual.dispose();
    _staffManual.dispose();
    super.dispose();
  }

  int? _pickedStudent() => _studentId == -1
      ? int.tryParse(_studentManual.text.trim())
      : _studentId;

  int? _pickedStaff() =>
      _staffId == -1 ? int.tryParse(_staffManual.text.trim()) : _staffId;

  Future<void> _enroll() async {
    final sid = _pickedStudent();
    final sec = _sectionId;
    if (sid == null || sec == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('need_ids'))));
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.postMap(
        '/admin/enrollments',
        data: {'student_id': sid, 'section_id': sec},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('enrolled_ok'))));
      setState(() {
        _studentId = null;
        _sectionId = null;
      });
      _studentManual.clear();
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

  Future<void> _assign() async {
    final staffId = _pickedStaff();
    final sec = _staffSectionId;
    if (staffId == null || sec == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('need_ids'))));
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.postMap(
        '/admin/sections/$sec/staff',
        data: {'staff_id': staffId, 'staff_role': _staffRole},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('assigned_ok'))));
      setState(() {
        _staffId = null;
        _staffSectionId = null;
      });
      _staffManual.clear();
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
        title: Text(tr('enroll_title')),
        actions: [
          IconButton(
            onPressed: () => refreshWithToast(context, _reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_EnrollData>(
        future: _dataFuture,
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
          final data = snapshot.data ??
              const _EnrollData(sections: [], students: [], staff: []);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr('enroll_student'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PersonPicker(
                      label: tr('pick_student'),
                      people: data.students,
                      idKey: 'student_id',
                      nameKey: 'student_name',
                      subKey: 'student_code',
                      value: _studentId,
                      manualController: _studentManual,
                      emptyHint: tr('dir_empty_pick'),
                      onChanged: (v) =>
                          setState(() => _studentId = v),
                    ),
                    const SizedBox(height: 12),
                    _SectionPicker(
                      label: tr('pick_section'),
                      sections: data.sections,
                      value: _sectionId,
                      onChanged: (v) =>
                          setState(() => _sectionId = v),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: tr('enroll_btn'),
                      icon: Icons.how_to_reg_rounded,
                      loading: _busy,
                      onPressed: _enroll,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr('assign_title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PersonPicker(
                      label: tr('pick_staff'),
                      people: data.staff,
                      idKey: 'staff_id',
                      nameKey: 'staff_name',
                      subKey: 'staff_type',
                      value: _staffId,
                      manualController: _staffManual,
                      emptyHint: tr('dir_empty_pick'),
                      onChanged: (v) => setState(() => _staffId = v),
                    ),
                    const SizedBox(height: 12),
                    _SectionPicker(
                      label: tr('pick_section'),
                      sections: data.sections,
                      value: _staffSectionId,
                      onChanged: (v) =>
                          setState(() => _staffSectionId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>(_staffRole),
                      initialValue: _staffRole,
                      decoration:
                          InputDecoration(labelText: tr('staff_role_l')),
                      items: [
                        DropdownMenuItem(
                          value: 'lecturer',
                          child: Text(tr('role_lecturer')),
                        ),
                        DropdownMenuItem(
                          value: 'TA',
                          child: Text(tr('role_ta')),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _staffRole = v ?? 'lecturer'),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: tr('assign_btn'),
                      icon: Icons.assignment_ind_outlined,
                      loading: _busy,
                      outlined: true,
                      onPressed: _assign,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr('enrollments'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<dynamic>>(
                      future: _enrollmentsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Text(
                            snapshot.error is ApiException
                                ? (snapshot.error as ApiException).message
                                : tr('cant_load'),
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 13,
                            ),
                          );
                        }
                        final rows = (snapshot.data ?? const [])
                            .whereType<Map>()
                            .map(Map<String, dynamic>.from)
                            .toList();
                        if (rows.isEmpty) {
                          return Text(
                            tr('no_enrollments'),
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 13,
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics:
                              const NeverScrollableScrollPhysics(),
                          itemCount: rows.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 16),
                          itemBuilder: (context, i) {
                            final e = rows[i];
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${e['student_name'] ?? ''} (${e['student_code'] ?? ''})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        '${ltr(e['course_code'] ?? '')} • ${ltr(e['section_name'] ?? '')} • ${ltr(e['status'] ?? '')}',
                                        style: const TextStyle(
                                          color: AppColors.textGrey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: tr('unenroll'),
                                  icon: const Icon(
                                    Icons.person_remove_outlined,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                  onPressed: () => _unenroll(e),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EnrollData {
  final List<Map<String, dynamic>> sections;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> staff;

  const _EnrollData({
    required this.sections,
    required this.students,
    required this.staff,
  });
}

/// Dropdown of people from the on-device directory, with names and IDs.
/// Falls back to a manual numeric field when the directory is empty
/// or "manual entry" is chosen.
class _PersonPicker extends StatelessWidget {
  final String label;
  final List<Map<String, dynamic>> people;
  final String idKey;
  final String nameKey;
  final String subKey;
  final int? value;
  final TextEditingController manualController;
  final String emptyHint;
  final ValueChanged<int?> onChanged;

  const _PersonPicker({
    required this.label,
    required this.people,
    required this.idKey,
    required this.nameKey,
    required this.subKey,
    required this.value,
    required this.manualController,
    required this.emptyHint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey<int?>(value),
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final p in people)
              if (Format.asInt(p[idKey]) != null)
                DropdownMenuItem(
                  value: Format.asInt(p[idKey])!,
                  child: Text(
                    '${p[nameKey] ?? '-'} • ${p[subKey] ?? ''} • ID ${p[idKey]}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            DropdownMenuItem(
              value: -1,
              child: Text(tr('manual_entry')),
            ),
          ],
          onChanged: onChanged,
        ),
        if (value == -1) ...[
          const SizedBox(height: 12),
          AppField(
            controller: manualController,
            label: tr('manual_entry'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ] else if (people.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              emptyHint,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

/// Dropdown of sections loaded from GET /admin/sections.
class _SectionPicker extends StatelessWidget {
  final String label;
  final List<Map<String, dynamic>> sections;
  final int? value;
  final ValueChanged<int?> onChanged;

  const _SectionPicker({
    required this.label,
    required this.sections,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: ValueKey<int?>(value),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
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
      onChanged: onChanged,
    );
  }
}
