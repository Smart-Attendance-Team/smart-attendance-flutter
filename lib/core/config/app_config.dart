// Default backend is the production server. Override at build time:
//   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000
abstract class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://smart-attendance-backend-production-affb.up.railway.app',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
