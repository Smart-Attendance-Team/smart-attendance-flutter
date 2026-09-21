import 'package:flutter/material.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../home/role_router.dart';
import '../data/auth_repository.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = AuthRepository();
      final res = await auth.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      // Real login always leaves demo mode.
      ApiClient.demoMode = false;
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoleRouter(
              userName: res.displayName,
              userRole: res.role,
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        AppLocale.toggle();
                        setState(() {});
                      },
                      child: Text(
                        tr('lang_tip'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Image.asset(
                  'assets/images/bua_logo.png',
                  width: 92,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.school_rounded,
                    size: 60,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr('welcome_back'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                tr('signin_sub'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppField(
                            controller: _email,
                            label: tr('email'),
                            hint: 'you@test.com',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.alternate_email_rounded,
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 14),
                          AppField(
                            controller: _password,
                            label: tr('password'),
                            hint: '••••••••',
                            obscure: _hidden,
                            prefixIcon: Icons.lock_outline_rounded,
                            validator: Validators.password,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _hidden
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _hidden = !_hidden),
                            ),
                          ),
                          const SizedBox(height: 20),
                          AppButton(
                            label: tr('sign_in'),
                            icon: Icons.login_rounded,
                            loading: _loading,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _enterDemo(context),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                            ),
                            label: Text(tr('demo_mode')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Enters offline demo mode: canned data, no network calls.
  /// Re-login for real turns it off automatically.
  static Future<void> _enterDemo(BuildContext context) async {
    const roles = ['student', 'lecturer', 'admin', 'auditor'];
    const roleKeys = [
      'role_student',
      'role_lecturer',
      'role_admin',
      'role_auditor',
    ];
    final role = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(tr('view_as')),
        children: [
          for (var i = 0; i < roles.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, roles[i]),
              child: Text(tr(roleKeys[i])),
            ),
        ],
      ),
    );
    if (role == null || !context.mounted) return;
    ApiClient.demoMode = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RoleRouter(userName: 'Demo User', userRole: role),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('demo_snack')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
