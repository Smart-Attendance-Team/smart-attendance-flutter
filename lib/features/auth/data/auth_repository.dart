import '../../../core/l10n/strings.dart' as l10n;
import '../../../core/network/api_client.dart';
import '../../../core/storage/session_manager.dart';

class LoginResult {
  final String displayName;
  final String role;
  const LoginResult({required this.displayName, required this.role});
}

/// POST /auth/login -> {token, role}, then GET /me -> {userId, role}.
class AuthRepository {
  final ApiClient _api;
  AuthRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.postMap(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final body = _unwrap(res);
    final token = _str(body, const ['token', 'access_token', 'jwt']);
    if (token.isEmpty) {
      throw ApiException(l10n.tr('e_no_token'));
    }

    var role = _str(body, const ['role'], fallback: 'student');
    final embedded = body['user'];
    if (embedded is Map) {
      role = _str(
        Map<String, dynamic>.from(embedded),
        const ['role'],
        fallback: role,
      );
    }

    var displayName = email.split('@').first;
    await SessionManager.save(token: token, role: role, email: email);

    try {
      final me = await _api.get('/me');
      if (me.data is Map) {
        final map = Map<String, dynamic>.from(me.data as Map);
        final confirmed = _str(map, const ['role']);
        if (confirmed.isNotEmpty) role = confirmed;
        final name = _str(map, const ['full_name', 'name']);
        if (name.isNotEmpty) displayName = name;
        await SessionManager.save(
          token: token,
          role: role,
          email: email,
          name: displayName,
        );
      }
    } catch (_) {
      // Profile is best-effort; login already succeeded.
    }

    return LoginResult(displayName: displayName, role: role);
  }

  Future<void> logout() => SessionManager.clear();

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    if ((json['token'] == null && json['access_token'] == null) &&
        json['data'] is Map) {
      final data = Map<String, dynamic>.from(json['data'] as Map);
      data.putIfAbsent('user', () => json['user']);
      return data;
    }
    return json;
  }

  static String _str(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return fallback;
  }
}
