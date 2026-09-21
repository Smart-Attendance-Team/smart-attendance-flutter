// Pass a custom backend URL at build time:
//   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000
//
// - Android emulator -> http://10.0.2.2:3000 (maps to the PC's localhost)
// - Physical device  -> PC LAN IP, e.g. http://192.168.1.50:3000
//   (phone + PC on the SAME Wi-Fi, backend on 0.0.0.0, firewall open)
// - Different networks -> use a tunnel URL (ngrok / cloudflare).
abstract class AppConfig {
  // Hardcoded LAN IP of the backend PC (hotspot network).
  // Override at build time if it changes:
  //   flutter run --dart-define=API_BASE_URL=http://<new-ip>:3000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.43.138:3000',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
