import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../l10n/strings.dart';
import '../storage/session_manager.dart';
import '../theme/app_colors.dart';
import 'ui.dart';
import '../../features/profile/presentation/profile_screen.dart';

/// Side drawer (swipe to open) shared by every dashboard:
/// user summary + My Profile + language + logout.
class AppDrawer extends StatelessWidget {
  final String userName;
  final String userRole;

  const AppDrawer({
    super.key,
    required this.userName,
    required this.userRole,
  });

  String get _roleLabel {
    switch (userRole.toLowerCase()) {
      case 'lecturer':
      case 'ta':
        return tr('role_lecturer');
      case 'admin':
      case 'administrator':
        return tr('role_admin');
      case 'auditor':
        return tr('role_auditor');
      default:
        return tr('role_student');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            decoration: const BoxDecoration(
              gradient: AppColors.headerGradient,
            ),
            child: FutureBuilder(
              future: SessionManager.read(),
              builder: (context, snapshot) {
                final email = snapshot.data?.email ?? '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.22),
                      child: Text(
                        userName.isEmpty
                            ? 'U'
                            : userName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        ltr(email),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _roleLabel.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(tr('profile')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    userName: userName,
                    userRole: userRole,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: Text(tr('lang_name')),
            trailing: Text(
              AppLocale.isArabic ? 'EN' : 'عربي',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              AppLocale.toggle();
            },
          ),
          const Spacer(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(
              Icons.logout_rounded,
              color: AppColors.error,
            ),
            title: Text(
              tr('logout_tip'),
              style: const TextStyle(color: AppColors.error),
            ),
            onTap: () => logout(context),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
