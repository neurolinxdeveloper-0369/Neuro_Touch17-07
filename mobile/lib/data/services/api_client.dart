import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import 'storage_service.dart';

class ApiClient {
  final Dio _dio;

  ApiClient._() : _dio = Dio() {
    _dio.options = BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  static final ApiClient instance = ApiClient._();
  Dio get dio => _dio;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await StorageService.instance.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 401 → try refresh
    if (err.response?.statusCode == 401) {
      final refreshToken = await StorageService.instance.getRefreshToken();
      if (refreshToken != null) {
        try {
          final resp = await Dio().post(
            '${ApiConstants.baseUrl}${ApiConstants.refreshToken}',
            data: jsonEncode({'refresh_token': refreshToken}),
            options: Options(headers: {'Content-Type': 'application/json'}),
          );
          final newToken = resp.data['access_token'] as String?;
          if (newToken != null) {
            await StorageService.instance.saveTokens(newToken, refreshToken);
            err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final retryResp = await _dio.fetch(err.requestOptions);
            return handler.resolve(retryResp);
          }
        } catch (_) {
          await StorageService.instance.clearAll();
        }
      }
    }
    return handler.next(err);
  }

  // Generic request helpers

  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? queryParameters}) =>
      _dio.get<T>(path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> patch<T>(String path, {dynamic data}) =>
      _dio.patch<T>(path, data: data);

  Future<Response<T>> delete<T>(String path) => _dio.delete<T>(path);
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient.instance;
});
