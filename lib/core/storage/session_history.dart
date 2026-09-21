import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sessions this device opened, grouped by user email.
/// The backend has no "my sessions" endpoint, so the app remembers
/// every session opened from here (id + title + time).
class OpenedSession {
  final String id;
  final String title;
  final String at;

  const OpenedSession({
    required this.id,
    required this.title,
    required this.at,
  });

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'at': at};

  factory OpenedSession.fromJson(Map<String, dynamic> json) => OpenedSession(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? ''}',
        at: '${json['at'] ?? ''}',
      );
}

abstract class SessionHistory {
  static const _storage = FlutterSecureStorage();
  static String _key(String email) => 'my_sessions_$email';

  static Future<List<OpenedSession>> list(String email) async {
    try {
      final raw = await _storage.read(key: _key(email));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => OpenedSession.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> add({
    required String email,
    required String id,
    required String title,
  }) async {
    final current = await list(email);
    final updated = [
      OpenedSession(
        id: id,
        title: title,
        at: DateTime.now().toIso8601String(),
      ),
      ...current.where((s) => s.id != id),
    ].take(20).toList();
    try {
      await _storage.write(
        key: _key(email),
        value: jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }
}
