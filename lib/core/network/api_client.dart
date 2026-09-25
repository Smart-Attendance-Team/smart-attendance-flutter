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
    try {
      final res = await _dio.patch(path, data: data);
      return asMap(res.data);
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  /// POST a raw CSV body (used by POST /admin/imports/students).
  Future<Map<String, dynamic>> postCsv(
    String path,
    String csv, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final res = await _dio.post(
        path,
        data: csv,
        queryParameters: queryParameters,
        options: Options(contentType: 'text/csv'),
      );
      return asMap(res.data);
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      await _dio.delete(path);
    } on DioException catch (e) {
      throw mapError(e);
    }
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
        if (msg == 'manually_recorded') {
          return ApiException(
            l10n.tr('r_manual'),
            statusCode: status,
            data: e.response?.data,
          );
        }
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
