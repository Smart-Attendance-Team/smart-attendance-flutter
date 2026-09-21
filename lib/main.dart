import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/l10n/app_locale.dart';
import 'core/network/api_client.dart';
import 'core/storage/session_manager.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/presentation/sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocale.load();
  // Load a saved server URL (typed in the app) before anything else.
  ApiClient.urlOverride = await SessionManager.readServerUrl();

  // Never show the harsh red crash page: log it, show a friendly box.
  FlutterError.onError = (details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };
  ErrorWidget.builder = (details) => Material(
        child: Container(
          padding: const EdgeInsets.all(24),
          color: AppColors.errorBg,
          alignment: Alignment.center,
          child: const Text(
            'Something went wrong while drawing this part. '
            'Go back and try again.',
            textAlign: TextAlign.center,
          ),
        ),
      );

  // Any 401 anywhere clears the session and returns to login.
  ApiServiceFactory.onUnauthenticated = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (_) => false,
    );
  };
  runApp(const CommunityAttendanceApp());
}
