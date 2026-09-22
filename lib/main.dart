import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/l10n/app_locale.dart';
import 'core/l10n/strings.dart';
import 'core/network/api_client.dart';
import 'core/storage/session_manager.dart';
import 'features/auth/presentation/sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocale.load();
  // Date symbols (e.g. Arabic month/day names) must be loaded or
  // DateFormat throws on devices with a non-English system locale —
  // which used to crash whole pages.
  await initializeDateFormatting();
  // Load a saved server URL (typed in the app) before anything else.
  ApiClient.urlOverride = await SessionManager.readServerUrl();

  // Widget build errors: never show a black/red page. If a pushed page
  // fails, go back to the previous working page; otherwise keep a plain
  // background. Either way show a bottom message only.
  FlutterError.onError = (details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };
  ErrorWidget.builder = (details) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final nav = navigatorKey.currentState;
      // Return to the last working page when possible.
      final popped = await nav?.maybePop() ?? false;
      if (!popped) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        // navigator key context is app-scoped, not tied to a disposed widget.
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(tr('went_wrong')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
    // Plain app background (never black/red) while recovering.
    return Container(color: const Color(0xFFF1F5F9));
  };

  // Any 401 anywhere clears the session and returns to login.
  ApiServiceFactory.onUnauthenticated = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (_) => false,
    );
  };
  runApp(const CommunityAttendanceApp());
}
