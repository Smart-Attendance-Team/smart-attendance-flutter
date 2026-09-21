import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/my_id_card.dart';
import '../../../core/widgets/ui.dart';
import 'correction_requests_screen.dart';
import 'live_roster_screen.dart';
import 'sessions_screen.dart';

class LecturerDashboard extends StatelessWidget {
  final String userName;
  const LecturerDashboard({super.key, required this.userName});

  void _askSession(BuildContext context) {
    final id = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('ask_session')),
        content: SingleChildScrollView(
          child: AppField(
            controller: id,
            label: tr('nm_session'),
            helper: tr('h_session_id'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () {
              final v = id.text.trim();
              Navigator.pop(context);
              if (v.isEmpty) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LiveRosterScreen(sessionId: v),
                ),
              );
            },
            child: Text(tr('open')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(userName: userName, userRole: 'lecturer'),
      body: Column(
        children: [
          DashboardHeader(
            name: userName,
            roleLabel: tr('role_lecturer'),
            subtitle: tr('lec_sub'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                MyIdCard(
                  metaKey: 'staff_id',
                  metaLabel: tr('staff_id_l'),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.event_available_rounded,
                  color: AppColors.primary,
                  title: tr('sessions'),
                  subtitle: tr('sessions_sub'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SessionsScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.groups_rounded,
                  color: AppColors.accent,
                  title: tr('roster'),
                  subtitle: tr('roster_sub'),
                  onTap: () => _askSession(context),
                ),
                const SizedBox(height: 12),
                MenuTile(
                  icon: Icons.assignment_late_outlined,
                  color: AppColors.warning,
                  title: tr('corr_rev'),
                  subtitle: tr('corr_rev_sub'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CorrectionRequestsScreen(),
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
