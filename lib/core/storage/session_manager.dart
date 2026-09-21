import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';

/// Persisted login session: token + role + display info.
class Session {
  final String token;
  final String role;
  final String email;
  final String? name;

  const Session({
    required this.token,
    required this.role,
    required this.email,
    this.name,
  });

  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }
}

class SessionManager {
  static const _storage = FlutterSecureStorage();

  static Future<void> save({
    required String token,
    required String role,
    required String email,
    String? name,
  }) async {
    await _storage.write(key: SessionKeys.token, value: token);
    await _storage.write(key: SessionKeys.role, value: role);
    await _storage.write(key: SessionKeys.email, value: email);
    if (name != null) {
      await _storage.write(key: SessionKeys.name, value: name);
    }
  }

  static Future<Session?> read() async {
    final token = await _storage.read(key: SessionKeys.token);
    if (token == null || token.isEmpty) return null;
    return Session(
      token: token,
      role: (await _storage.read(key: SessionKeys.role)) ?? 'student',
      email: (await _storage.read(key: SessionKeys.email)) ?? '',
      name: await _storage.read(key: SessionKeys.name),
    );
  }

  static Future<void> updateRole(String role) =>
      _storage.write(key: SessionKeys.role, value: role);

  static Future<String?> readServerUrl() =>
      _storage.read(key: SessionKeys.serverUrl);

  static Future<void> saveServerUrl(String url) =>
      _storage.write(key: SessionKeys.serverUrl, value: url);

  /// IDs the admin hands out once (staff_id / student_id), saved per account
  /// so each user always sees their own assignment/enrollment number.
  static Future<void> saveMeta(String email, String key, String value) =>
      _storage.write(key: 'meta_${email}_$key', value: value);

  static Future<String?> readMeta(String email, String key) =>
      _storage.read(key: 'meta_${email}_$key');

  static Future<void> clear() => _storage.deleteAll();
}
