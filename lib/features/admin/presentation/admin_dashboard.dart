import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/ui.dart';
import 'courses_screen.dart';
import 'departments_screen.dart';
import 'directory_screen.dart';
import 'enrollment_screen.dart';
import 'people_screen.dart';
import 'reports_screen.dart';
import 'rooms_screen.dart';
import 'sections_screen.dart';
import 'timetable_screen.dart';

class AdminDashboard extends StatelessWidget {
  final String userName;
  const AdminDashboard({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    void go(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      drawer: AppDrawer(userName: userName, userRole: 'admin'),
      body: Column(
        children: [
          DashboardHeader(
            name: userName,
            roleLabel: tr('role_admin'),
            subtitle: tr('adm_sub'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                MenuTile(
                  icon: Icons.account_balance_rounded,
                  color: Colors.teal,
                  title: tr('departments'),
                  subtitle: tr('departments_sub'),
                  onTap: () => go(const DepartmentsScreen()),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.menu_book_rounded,
                  color: AppColors.primary,
                  title: tr('courses'),
                  subtitle: tr('courses_sub'),
                  onTap: () => go(const CoursesScreen()),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.meeting_room_outlined,
                  color: AppColors.accent,
                  title: tr('rooms'),
                  subtitle: tr('rooms_sub'),
                  onTap: () => go(const RoomsScreen()),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.group_work_outlined,
                  color: Colors.purple,
                  title: tr('sections'),
                  subtitle: tr('sections_sub'),
                  onTap: () => go(const SectionsScreen()),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.calendar_month_rounded,
                  color: Colors.orange,
                  title: tr('timetable'),
                  subtitle: tr('timetable_sub'),
                  onTap: () => go(const TimetableScreen()),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.school_rounded,
                  color: Colors.indigo,
                  title: tr('students'),
                  subtitle: tr('students_sub'),
                  onTap: () => go(const DirectoryScreen(students: true)),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.co_present_rounded,
                  color: Colors.brown,
                  title: tr('lecturers'),
                  subtitle: tr('lecturers_sub'),
                  onTap: () => go(const DirectoryScreen(students: false)),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.person_add_alt_rounded,
                  color: AppColors.success,
                  title: tr('people'),
                  subtitle: tr('people_sub'),
                  onTap: () => go(const PeopleScreen()),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.how_to_reg_rounded,
                  color: AppColors.info,
                  title: tr('enrollment'),
                  subtitle: tr('enrollment_sub'),
                  onTap: () => go(const EnrollmentScreen()),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.analytics_rounded,
                  color: AppColors.error,
                  title: tr('reports'),
                  subtitle: tr('reports_sub'),
                  onTap: () => go(const ReportsScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
