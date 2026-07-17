import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user.model.dart';
import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';

// ─── Response types ───────────────────────────────────────────────────────────

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class OtpVerifyResponse {
  final bool success;
  final String? resetToken;

  const OtpVerifyResponse({required this.success, this.resetToken});

  factory OtpVerifyResponse.fromJson(Map<String, dynamic> json) {
    return OtpVerifyResponse(
      success: json['success'] as bool? ?? true,
      resetToken: json['reset_token'] as String?,
    );
  }
}

// ─── AuthService ──────────────────────────────────────────────────────────────

class AuthService {
  final ApiService _api;

  static final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: const String.fromEnvironment('GOOGLE_CLIENT_ID').isEmpty
        ? null
        : const String.fromEnvironment('GOOGLE_CLIENT_ID'),
  );

  AuthService(this._api);

  // ─── Login (Obsolete) ─────────────────────────────────────────────────────

  Future<AuthResponse> login(
    String contact,
    String password,
    bool isEmail,
  ) async {
    throw UnimplementedError('Password login is not supported');
  }

  // ─── Register (Obsolete) ──────────────────────────────────────────────────

  Future<AuthResponse> register(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    throw UnimplementedError('Password registration is not supported');
  }

  // ─── Google Sign-In ───────────────────────────────────────────────────────

  Future<AuthResponse> googleSignIn() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign in cancelled');

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('Failed to get Google ID token');

    final data = await _api.post(ApiConstants.googleAuth, {
      'id_token': idToken,
    });
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  // ─── Apple Sign-In (Obsolete) ─────────────────────────────────────────────

  Future<AuthResponse> appleSignIn() async {
    throw UnimplementedError('Apple authentication is not supported');
  }

  // ─── Forgot Password (Obsolete) ───────────────────────────────────────────

  Future<void> forgotPassword(String contact) async {
    throw UnimplementedError('Password recovery is not supported');
  }

  // ─── Verify OTP (Obsolete) ────────────────────────────────────────────────

  Future<OtpVerifyResponse> verifyOtp(
    String contact,
    String otp,
    String purpose,
  ) async {
    throw UnimplementedError('Legacy verify OTP is not supported');
  }

  // ─── Reset Password (Obsolete) ────────────────────────────────────────────

  Future<void> resetPassword(String resetToken, String newPassword) async {
    throw UnimplementedError('Password reset is not supported');
  }

  // ─── Refresh Token ────────────────────────────────────────────────────────

  Future<AuthResponse> refreshToken(String token) async {
    final data = await _api.post(ApiConstants.refreshToken, {
      'refresh_token': token,
    });
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  // ─── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiServiceProvider));
});
