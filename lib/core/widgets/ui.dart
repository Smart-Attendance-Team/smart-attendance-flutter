import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../l10n/app_locale.dart';
import '../l10n/strings.dart';
import '../storage/session_manager.dart';
import '../../features/auth/presentation/sign_in_screen.dart';

// ------------------------------------------------------------ buttons --
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool outlined;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );
    if (outlined) {
      return OutlinedButton(onPressed: loading ? null : onPressed, child: child);
    }
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: child,
    );
  }
}

// -------------------------------------------------------------- field --
class AppField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final TextInputType keyboardType;
  final bool obscure;
  final int maxLines;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final void Function(String)? onChanged;

  const AppField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.keyboardType = TextInputType.text,
    this.obscure = false,
    this.maxLines = 1,
    this.validator,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      maxLines: maxLines,
      validator: validator,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ---------------------------------------------------------------- card --
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// --------------------------------------------------------------- states --
class AppLoading extends StatelessWidget {
  final String? message;
  const AppLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: const TextStyle(color: AppColors.textGrey)),
          ],
        ],
      ),
    );
  }
}

class AppEmpty extends StatelessWidget {
  final String message;
  final IconData icon;
  const AppEmpty({super.key, required this.message, this.icon = Icons.inbox});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGrey, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class AppError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String? hint;
  const AppError({
    super.key,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: AppButton(
                label: tr('retry'),
                icon: Icons.refresh,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- header --
/// Gradient greeting header used by all dashboards.
class DashboardHeader extends StatelessWidget {
  final String name;
  final String roleLabel;
  final String? subtitle;
  final List<Widget>? stats;

  const DashboardHeader({
    super.key,
    required this.name,
    required this.roleLabel,
    this.subtitle,
    this.stats,
  });

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length > 1 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () {
                    try {
                      Scaffold.of(context).openDrawer();
                    } catch (_) {}
                  },
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          roleLabel.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr('lang_tip'),
                  onPressed: () => AppLocale.toggle(),
                  icon: Text(
                    AppLocale.isArabic ? 'EN' : 'ع',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr('logout_tip'),
                  onPressed: () => logout(context),
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                ),
              ],
            ),
            if (sub != null) ...[
              const SizedBox(height: 12),
              Text(
                sub,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ],
            if (stats != null) ...[
              const SizedBox(height: 16),
              Row(children: stats!),
            ],
          ],
        ),
      ),
    );
  }
}

class HeaderStat extends StatelessWidget {
  final String value;
  final String label;
  const HeaderStat({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ menu tile --
class MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const MenuTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------- status chip --
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = AppColors.statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        trStatus(status),
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- section bar --
class SectionBar extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionBar({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    final act = action;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          act ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- logout --
/// Runs a manual refresh and always confirms visibly, so the user can
/// tell the button did something even when the data is unchanged
/// (e.g. instant demo data or an already-fresh server).
Future<void> refreshWithToast(
  BuildContext context,
  Future<void> Function() reload,
) async {
  await reload();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('updated_ok')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

Future<void> logout(BuildContext context) async {
  await SessionManager.clear();
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (_) => false,
    );
  }
}

// ---------------------------------------------------------- validators --
abstract class Validators {
  static String? required(String? v, [String nameKey = 'nm_value']) {
    if (v == null || v.trim().isEmpty) {
      return tr('err_required', {'name': tr(nameKey)});
    }
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return tr('err_email_req');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
      return tr('err_email_bad');
    }
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return tr('err_pass_req');
    return null;
  }

  static String? min(String? v, int n, [String nameKey = 'nm_value']) {
    if (v == null || v.trim().length < n) {
      return tr('err_min', {'name': tr(nameKey), 'n': '$n'});
    }
    return null;
  }

  static String? number(String? v, [String nameKey = 'nm_value']) {
    if (v == null || v.trim().isEmpty) {
      return tr('err_required', {'name': tr(nameKey)});
    }
    if (int.tryParse(v.trim()) == null) {
      return tr('err_num', {'name': tr(nameKey)});
    }
    return null;
  }
}
