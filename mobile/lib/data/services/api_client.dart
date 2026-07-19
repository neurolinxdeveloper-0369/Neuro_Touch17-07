import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import 'storage_service.dart';

class ApiClient {
  final Dio _dio;
  bool _isRefreshing = false;
  final List<void Function(String?)> _refreshQueue = [];

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
    if (err.response?.statusCode == 401) {
      // If refresh is already in progress, queue this request
      if (_isRefreshing) {
        _refreshQueue.add((newToken) {
          if (newToken != null) {
            err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            _dio.fetch(err.requestOptions).then(
              (value) => handler.resolve(value),
              onError: (e) => handler.reject(e),
            );
          } else {
            handler.reject(err);
          }
        });
        return;
      }

      _isRefreshing = true;
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
            
            // Resolve current request
            err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final retryResp = await _dio.fetch(err.requestOptions);
            
            // Flush queue
            for (var callback in _refreshQueue) {
              callback(newToken);
            }
            _refreshQueue.clear();
            _isRefreshing = false;
            
            return handler.resolve(retryResp);
          }
        } catch (_) {
          // Refresh failed, clear everything
          await StorageService.instance.clearAll();
          for (var callback in _refreshQueue) {
            callback(null);
          }
          _refreshQueue.clear();
          _isRefreshing = false;
        }
      } else {
        _isRefreshing = false;
      }
    }
    return handler.next(err);
  }

  // Generic request helpers
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) =>
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
