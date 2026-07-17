import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
import '../../core/constants/api_constants.dart';

// ─── ApiException ─────────────────────────────────────────────────────────────

enum ApiExceptionType { network, server, auth, notFound, unknown }

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final ApiExceptionType type;

  const ApiException({
    this.statusCode,
    required this.message,
    this.type = ApiExceptionType.unknown,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// ─── ApiService ───────────────────────────────────────────────────────────────

class ApiService {
  late final Dio _dio;
  final StorageService _storage;

  // Emits when a 401 cannot be refreshed (force logout signal)
  final _logoutController = StreamController<void>.broadcast();
  Stream<void> get logoutStream => _logoutController.stream;

  ApiService(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  // ─── Interceptor callbacks ──────────────────────────────────────────────────

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  void _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    handler.next(response);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (error.response?.statusCode == 401) {
      // Attempt token refresh
      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken == null) throw Exception('No refresh token');

        final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
        final refreshResp = await refreshDio.post(
          ApiConstants.refreshToken,
          data: {'refresh_token': refreshToken},
        );

        final newAccessToken =
            refreshResp.data['access_token'] as String;
        final newRefreshToken =
            refreshResp.data['refresh_token'] as String? ?? refreshToken;

        await _storage.saveTokens(newAccessToken, newRefreshToken);

        // Retry original request
        error.requestOptions.headers['Authorization'] =
            'Bearer $newAccessToken';
        final retryResponse = await _dio.fetch(error.requestOptions);
        handler.resolve(retryResponse);
        return;
      } catch (_) {
        // Refresh failed — signal logout
        _logoutController.add(null);
      }
    }
    handler.next(error);
  }

  // ─── HTTP helpers ───────────────────────────────────────────────────────────

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParams,
      );
      return response.data;
    } on DioException catch (e) {
      throw _convertDioException(e);
    }
  }

  Future<dynamic> post(String path, dynamic data) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _convertDioException(e);
    }
  }

  Future<dynamic> put(String path, dynamic data) async {
    try {
      final response = await _dio.put(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _convertDioException(e);
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return response.data;
    } on DioException catch (e) {
      throw _convertDioException(e);
    }
  }

  Future<dynamic> postFormData(String path, FormData formData) async {
    try {
      final response = await _dio.post(path, data: formData);
      return response.data;
    } on DioException catch (e) {
      throw _convertDioException(e);
    }
  }

  // ─── Exception conversion ───────────────────────────────────────────────────

  ApiException _convertDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const ApiException(
        message: 'No internet connection. Please check your network.',
        type: ApiExceptionType.network,
      );
    }

    final statusCode = e.response?.statusCode;
    final serverMessage = _extractMessage(e.response?.data);

    if (statusCode == 401) {
      return ApiException(
        statusCode: statusCode,
        message: serverMessage ?? 'Unauthorized. Please sign in again.',
        type: ApiExceptionType.auth,
      );
    }

    if (statusCode == 404) {
      return ApiException(
        statusCode: statusCode,
        message: serverMessage ?? 'Resource not found.',
        type: ApiExceptionType.notFound,
      );
    }

    if (statusCode != null && statusCode >= 500) {
      return ApiException(
        statusCode: statusCode,
        message: serverMessage ?? 'Server error. Please try again later.',
        type: ApiExceptionType.server,
      );
    }

    return ApiException(
      statusCode: statusCode,
      message: serverMessage ?? e.message ?? 'An unexpected error occurred.',
      type: ApiExceptionType.unknown,
    );
  }

  String? _extractMessage(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      return data['message'] as String? ??
          data['error'] as String? ??
          data['detail'] as String?;
    }
    if (data is String && data.isNotEmpty) return data;
    return null;
  }

  void dispose() {
    _logoutController.close();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final apiServiceProvider = Provider<ApiService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final service = ApiService(storage);
  ref.onDispose(service.dispose);
  return service;
});
