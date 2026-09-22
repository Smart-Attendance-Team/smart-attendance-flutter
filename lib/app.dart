import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/l10n/app_locale.dart';
import 'core/l10n/strings.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global 401 handler: every [ApiClient] can redirect to login on expiry.
abstract class ApiServiceFactory {
  static void Function()? onUnauthenticated;

  static ApiClient create() =>
      ApiClient(onUnauthenticated: onUnauthenticated);
}

class CommunityAttendanceApp extends StatelessWidget {
  const CommunityAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocale.current,
      builder: (_, locale, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        title: tr('app_name'),
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SplashScreen(),
      ),
    );
  }
}
