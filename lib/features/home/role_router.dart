import 'package:flutter/material.dart';

import '../admin/presentation/admin_dashboard.dart';
import '../auditor/presentation/auditor_dashboard.dart';
import '../lecturer/presentation/lecturer_dashboard.dart';
import '../student/presentation/student_dashboard.dart';

/// Sends each role to its own home after login / splash.
class RoleRouter extends StatelessWidget {
  final String userRole;
  final String userName;

  const RoleRouter({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    switch (userRole.toLowerCase()) {
      case 'lecturer':
      case 'ta':
        return LecturerDashboard(userName: userName);
      case 'admin':
      case 'administrator':
        return AdminDashboard(userName: userName);
      case 'auditor':
        return AuditorDashboard(userName: userName);
      case 'student':
      default:
        return StudentDashboard(userName: userName);
    }
  }
}
