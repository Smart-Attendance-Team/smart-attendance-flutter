import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
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
  final _student = TextEditingController();
  final _section = TextEditingController();
  final _staff = TextEditingController();
  final _staffSection = TextEditingController();
  var _staffRole = 'lecturer';
  bool _busy = false;

  @override
  void dispose() {
    _student.dispose();
    _section.dispose();
    _staff.dispose();
    _staffSection.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    final sid = int.tryParse(_student.text.trim());
    final sec = int.tryParse(_section.text.trim());
    if (sid == null || sec == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('need_ids'))),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.postMap(
        '/admin/enrollments',
        data: {'student_id': sid, 'section_id': sec},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('enrolled_ok'))),
      );
      _student.clear();
      _section.clear();
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

  Future<void> _assign() async {
    final staffId = int.tryParse(_staff.text.trim());
    final sec = int.tryParse(_staffSection.text.trim());
    if (staffId == null || sec == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('need_ids'))),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.postMap(
        '/admin/sections/$sec/staff',
        data: {'staff_id': staffId, 'staff_role': _staffRole},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('assigned_ok'))),
      );
      _staff.clear();
      _staffSection.clear();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('enroll_title'))),
      body: ListView(
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
                AppField(
                  controller: _student,
                  label: tr('nm_student'),
                  helper: tr('h_student_id'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.school_outlined,
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _section,
                  label: tr('nm_section'),
                  helper: tr('h_section_id'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.group_work_outlined,
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
                AppField(
                  controller: _staff,
                  label: 'Staff ID',
                  helper: tr('h_staff_id'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _staffSection,
                  label: tr('nm_section'),
                  helper: tr('h_section_id'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.group_work_outlined,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _staffRole,
                  decoration:
                      InputDecoration(labelText: tr('staff_role_l')),
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
        ],
      ),
    );
  }
}
