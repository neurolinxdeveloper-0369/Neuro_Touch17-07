import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.model.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../../core/constants/api_constants.dart';

class AuthRepository {
  final ApiClient _api;
  final StorageService _storage;

  AuthRepository({required ApiClient api, required StorageService storage})
      : _api = api,
        _storage = storage;

  Future<UserModel> googleAuth(String idToken) async {
    final resp = await _api.post(
      ApiConstants.googleAuth,
      data: {'id_token': idToken},
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);

    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveTokens(
      data['access_token'] as String,
      data['refresh_token'] as String,
    );
    await _storage.saveUser(user);
    return user;
  }

  Future<void> sendOtp(String phone) async {
    final resp = await _api.post(ApiConstants.sendOtp, data: {
      'phone': phone,
    });
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
  }

  Future<UserModel> verifyOtpLogin({
    required String phone,
    required String otp,
    String? name,
  }) async {
    final resp = await _api.post(ApiConstants.verifyOtpLogin, data: {
      'phone': phone,
      'otp': otp,
      if (name != null && name.isNotEmpty) 'name': name,
    });
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);

    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveTokens(
      data['access_token'] as String,
      data['refresh_token'] as String,
    );
    await _storage.saveUser(user);
    return user;
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }

  UserModel? getCachedUser() => _storage.getUser();

  Future<bool> isLoggedIn() async {
    final token = await _storage.getAccessToken();
    return token != null;
  }
}

class MfaRequiredException implements Exception {
  final String? tempToken;
  MfaRequiredException(this.tempToken);

  @override
  String toString() => 'MFA required';
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.read(apiClientProvider),
    storage: ref.read(storageServiceProvider),
  );
});
