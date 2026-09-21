import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/ui.dart';
import 'audit_history_screen.dart';
import 'flags_screen.dart';

class AuditorDashboard extends StatelessWidget {
  final String userName;
  const AuditorDashboard({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(userName: userName, userRole: 'auditor'),
      body: Column(
        children: [
          DashboardHeader(
            name: userName,
            roleLabel: tr('role_auditor'),
            subtitle: tr('aud_sub'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                MenuTile(
                  icon: Icons.history_rounded,
                  color: AppColors.accent,
                  title: tr('audit'),
                  subtitle: tr('audit_sub'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AuditHistoryScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.flag_outlined,
                  color: AppColors.warning,
                  title: tr('flags'),
                  subtitle: tr('flags_sub'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FlagsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
