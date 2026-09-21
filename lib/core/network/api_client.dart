import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../l10n/strings.dart' as l10n;

/// Error surfaced to the UI with a human-readable [message].
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;
}

/// Single HTTP layer for the app.
///
/// - Injects `Authorization: Bearer <token>` automatically.
/// - Clears the session + calls [onUnauthenticated] on 401.
/// - Maps backend `{error: ...}` / FastAPI `{detail: ...}` shapes to text.
/// - Never crashes on unexpected bodies (lists, HTML, null).
class ApiClient {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final void Function()? onUnauthenticated;
  late final Dio _dio;

  /// Runtime server override (set from the login screen, survives restarts).
  /// Loaded once in main() before runApp.
  static String? urlOverride;

  /// When true, all requests return canned empty data instead of
  /// touching the network (lets you browse the UI with no backend).
  static bool demoMode = false;

  static String get effectiveBaseUrl =>
      urlOverride ?? AppConfig.baseUrl;

  ApiClient({this.onUnauthenticated, Dio? dio, String? baseUrl}) {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl ?? effectiveBaseUrl,
            connectTimeout: AppConfig.connectTimeout,
            receiveTimeout: AppConfig.receiveTimeout,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
          ),
        );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
          logPrint: (o) => debugPrint('[API] $o'),
        ),
      );
    }

    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await _storage.read(key: SessionKeys.token);
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (_) {
            // Storage failures must never block a request.
          }
          handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              await _storage.deleteAll();
            } catch (_) {}
            onUnauthenticated?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  Dio get client => _dio;
  String get baseUrl => _dio.options.baseUrl;

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (demoMode) {
      return Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: _demoBody(path),
      );
    }
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await get(path, queryParameters: queryParameters);
    return asList(res.data);
  }

  Future<Map<String, dynamic>> postMap(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    if (demoMode) {
      if (path == '/attendance/scan') {
        return {'accepted': true, 'attendance_status': 'present'};
      }
      if (path == '/sessions/open') {
        return {'session_id': 1, 'status': 'open'};
      }
      if (path.endsWith('/close')) {
        return {'status': 'closed'};
      }
      if (path == '/sessions/1/qr' || path.endsWith('/qr')) {
        return {'token': 'DEMO-QR-TOKEN', 'expires_in_seconds': 20};
      }
      return {'ok': true};
    }
    try {
      final res = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return asMap(res.data);
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  Future<Map<String, dynamic>> patchMap(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    if (demoMode) return {'ok': true};
    try {
      final res = await _dio.patch(path, data: data);
      return asMap(res.data);
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  Future<void> delete(String path) async {
    if (demoMode) return;
    try {
      await _dio.delete(path);
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  // ------------------------------------------------------------ helpers --
  /// Canned GET bodies used only in demo mode.
  static dynamic _demoBody(String path) {
    if (path == '/health') return {'status': 'ok'};
    if (path == '/me') return {'userId': 1, 'role': 'student'};
    if (path.endsWith('/roster')) {
      return {
        'session_id': 1,
        'session_status': 'open',
        'summary': {
          'total': 3,
          'present': 2,
          'late': 1,
          'excused': 0,
          'absent': 0,
        },
        'students': [
          {
            'attendance_id': 11,
            'student_code': 'S1001',
            'student_name': 'Demo Student 1',
            'attendance_status': 'present',
            'minutes_late': 0,
            'source': 'qr',
          },
          {
            'attendance_id': 12,
            'student_code': 'S1002',
            'student_name': 'Demo Student 2',
            'attendance_status': 'late',
            'minutes_late': 18,
            'source': 'qr',
          },
          {
            'attendance_id': 13,
            'student_code': 'S1003',
            'student_name': 'Demo Student 3',
            'attendance_status': 'present',
            'minutes_late': 0,
            'source': 'manual',
          },
        ],
      };
    }
    if (path == '/flags') {
      return {
        'available': true,
        'count': 1,
        'flags': [
          {
            'type': 'low_attendance',
            'student_code': 'S1003',
            'student_name': 'Demo Student 3',
            'course_code': 'CS101',
            'section_name': 'Section 1',
            'explanation': 'Attended 1 of 3 counted sessions (33%)',
          },
        ],
      };
    }
    if (path == '/audit-events') {
      return {
        'count': 1,
        'events': [
          {
            'audit_id': 1,
            'action': 'attendance.manual_update',
            'entity_type': 'attendance',
            'entity_id': 11,
            'actor_email': 'lecturer@test.com',
            'actor_role': 'lecturer',
            'created_at': '2026-09-20T10:00:00Z',
          },
        ],
      };
    }
    if (path == '/reports/attendance') {
      return {
        'summary': {
          'total': 2,
          'present': 1,
          'late': 1,
          'excused': 0,
          'absent': 0,
          'attendance_rate_percent': 100,
        },
        'rows': [
          {
            'student_name': 'Demo Student 1',
            'student_code': 'S1001',
            'course_code': 'CS101',
            'session_date': '2026-09-18',
            'attendance_status': 'present',
            'source': 'qr',
          },
          {
            'student_name': 'Demo Student 2',
            'student_code': 'S1002',
            'course_code': 'CS101',
            'session_date': '2026-09-18',
            'attendance_status': 'late',
            'source': 'qr',
          },
        ],
      };
    }
    if (path == '/attendance/me') {
      return [
        {
          'attendance_id': 11,
          'course_code': 'CS101',
          'course_name': 'Intro to CS',
          'session_date': '2026-09-18',
          'attendance_status': 'present',
          'minutes_late': 0,
        },
      ];
    }
    if (path == '/corrections/mine' || path == '/corrections/pending') {
      return [
        {
          'request_id': 1,
          'attendance_id': 11,
          'student_code': 'S1001',
          'student_name': 'Demo Student 1',
          'course_code': 'CS101',
          'session_date': '2026-09-18',
          'current_status': 'absent',
          'requested_status': 'present',
          'reason': 'QR did not scan that day',
          'status': 'pending',
          'created_at': '2026-09-19T10:00:00Z',
        },
      ];
    }
    if (path == '/admin/courses') {
      return [
        {'course_id': 1, 'course_code': 'CS101', 'course_name': 'Intro to CS'},
      ];
    }
    if (path == '/admin/rooms') {
      return [
        {
          'room_id': 1,
          'room_name': 'Hall A',
          'room_type': 'lecture',
          'capacity': 120,
        },
      ];
    }
    if (path == '/admin/sections') {
      return [
        {
          'section_id': 2,
          'course_id': 1,
          'section_name': 'Section 1',
          'semester': 'Fall 2026',
        },
      ];
    }
    if (path == '/admin/timetable-slots') {
      return [
        {
          'slot_id': 5,
          'section_id': 2,
          'room_id': 1,
          'day_of_week': 'Monday',
          'start_time': '08:00',
          'end_time': '10:00',
        },
      ];
    }
    return {};
  }

  // ---------------------------------------------------------- parsing --
  static List<dynamic> asList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      for (final key in const [
        'data',
        'items',
        'results',
        'records',
        'rows',
        'events',
        'students',
        'flags',
      ]) {
        if (data[key] is List) return data[key] as List<dynamic>;
      }
    }
    return const [];
  }

  static Map<String, dynamic> asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  /// Reads `error` / `message` / `detail` from common backend shapes.
  static String? serverMessage(dynamic data) {
    if (data is Map) {
      for (final key in const ['message', 'detail', 'error', 'msg']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value;
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is Map && first['msg'] is String) {
            return first['msg'] as String;
          }
          return first.toString();
        }
      }
      // Scan rejection shape: {accepted: false, reason: ...}
      final reason = data['reason'];
      if (reason is String && reason.isNotEmpty) return reason;
    }
    if (data is String && data.trim().isNotEmpty) {
      if (data.trimLeft().startsWith('<')) return null; // HTML page
      return data;
    }
    return null;
  }

  static ApiException mapError(DioException e) {
    final status = e.response?.statusCode;
    final msg = serverMessage(e.response?.data);

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiException(
        l10n.tr('e_timeout'),
        statusCode: status,
        data: e.response?.data,
      );
    }
    if (e.type == DioExceptionType.connectionError) {
      return ApiException(
        l10n.tr('e_conn', {'url': effectiveBaseUrl}),
        statusCode: status,
        data: e.response?.data,
      );
    }
    switch (status) {
      case 400:
      case 422:
        return ApiException(
          msg ?? l10n.tr('e_bad'),
          statusCode: status,
          data: e.response?.data,
        );
      case 401:
        return ApiException(
          l10n.tr('e_login'),
          statusCode: status,
          data: e.response?.data,
        );
      case 403:
        return ApiException(
          msg ?? l10n.tr('e_forbidden'),
          statusCode: status,
          data: e.response?.data,
        );
      case 404:
        return ApiException(
          msg ?? l10n.tr('e_404'),
          statusCode: status,
          data: e.response?.data,
        );
      case 409:
        return ApiException(
          msg ?? l10n.tr('e_409'),
          statusCode: status,
          data: e.response?.data,
        );
      case 429:
        return ApiException(
          l10n.tr('e_429'),
          statusCode: status,
          data: e.response?.data,
        );
      default:
        if (status != null && status >= 500) {
          return ApiException(
            msg ?? l10n.tr('e_500', {'code': '$status'}),
            statusCode: status,
            data: e.response?.data,
          );
        }
    }
    return ApiException(
      msg ?? l10n.tr('e_fail', {'t': e.type.name}),
      statusCode: status,
      data: e.response?.data,
    );
  }
}

/// Secure-storage keys (single source of truth).
abstract class SessionKeys {
  static const token = 'jwt_token';
  static const role = 'user_role';
  static const email = 'user_email';
  static const name = 'user_name';
  static const serverUrl = 'server_url';
}
