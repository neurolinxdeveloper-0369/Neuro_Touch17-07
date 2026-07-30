import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user.model.dart';
import '../data/repositories/auth.repository.dart';
import '../data/services/storage_service.dart';
import '../data/services/api_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;
  final bool isMfaRequired;
  final String? mfaTempToken;
  final bool isInitialized;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.isMfaRequired = false,
    this.mfaTempToken,
    this.isInitialized = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
    bool clearError = false,
    bool? isMfaRequired,
    String? mfaTempToken,
    bool? isInitialized,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: clearError ? null : (error ?? this.error),
        isMfaRequired: isMfaRequired ?? this.isMfaRequired,
        mfaTempToken: mfaTempToken ?? this.mfaTempToken,
        isInitialized: isInitialized ?? this.isInitialized,
      );

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final StorageService _storage;
  final ApiService _apiService;
  final GoogleSignIn _googleSignIn;

  AuthController({
    required AuthRepository repo,
    required StorageService storage,
    required ApiService apiService,
  })  : _repo = repo,
        _storage = storage,
        _apiService = apiService,
        _googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
          serverClientId: const String.fromEnvironment('GOOGLE_CLIENT_ID').isEmpty
              ? null
              : const String.fromEnvironment('GOOGLE_CLIENT_ID'),
        ),
        super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final stopwatch = Stopwatch()..start();
    try {
      state = state.copyWith(status: AuthStatus.loading);
      final cached = await _storage.getUser();
      final token = await _storage.getAccessToken();

      // We'll store the target state here but only apply it after 5 seconds
      AuthState targetState;

      if (cached != null && token != null) {
        targetState = AuthState(status: AuthStatus.authenticated, user: cached);
      } else {
        // Silent Google Sign-In attempt
        final silentAccount = await _googleSignIn.signInSilently();
        if (silentAccount != null) {
          final auth = await silentAccount.authentication;
          if (auth.idToken != null) {
            final user = await _repo.googleAuth(auth.idToken!);
            targetState = AuthState(status: AuthStatus.authenticated, user: user);
          } else {
            targetState = const AuthState(status: AuthStatus.unauthenticated);
          }
        } else {
          targetState = const AuthState(status: AuthStatus.unauthenticated);
        }
      }

      // Ensure at least 5 seconds have passed
      final elapsed = stopwatch.elapsed;
      if (elapsed.inSeconds < 5) {
        await Future.delayed(Duration(seconds: 5) - elapsed);
      }
      state = targetState.copyWith(isInitialized: true);
      
      // Upload FCM token if authenticated
      if (state.isAuthenticated) {
        _syncFCMToken();
      }
    } catch (e) {
      print('Auth initialization error: $e');
      final elapsed = stopwatch.elapsed;
      if (elapsed.inSeconds < 5) {
        await Future.delayed(Duration(seconds: 5) - elapsed);
      }
      state = const AuthState(status: AuthStatus.unauthenticated, isInitialized: true);
    } finally {
      stopwatch.stop();
    }
  }

  // --- Register ---

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _repo.sendOtp(phone);
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: _parseError(e),
      );
      rethrow;
    }
  }

  Future<void> verifyOtpLogin({
    required String phone,
    required String otp,
    String? name,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    final stopwatch = Stopwatch()..start();
    try {
      final user = await _repo.verifyOtpLogin(
        phone: phone,
        otp: otp,
        name: name,
      );
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 3000) {
        await Future.delayed(Duration(milliseconds: 3000 - elapsed));
      }
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: _parseError(e),
      );
      rethrow;
    }
  }

  // --- Google Sign In ---

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }
      final auth = await account.authentication;
      if (auth.idToken == null) throw Exception('Google sign in failed');

      final user = await _repo.googleAuth(auth.idToken!);
      state = AuthState(status: AuthStatus.authenticated, user: user, isInitialized: true);
      
      _syncFCMToken();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: _parseError(e),
      );
      rethrow;
    }
  }

  Future<void> _syncFCMToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) {
        await _apiService.updateFCMToken(token);
      }
    } catch (e) {
      debugPrint('Failed to sync FCM token locally: $e');
    }
  }// --- Legacy Password Stubs (Obsolete) ---
  Future<void> register({required String name, String? email, String? phone, required String password}) async {}
  Future<bool> forgotPassword({required String contact, required bool isEmail}) async => false;
  Future<bool> resetPassword({required String resetToken, required String newPassword}) async => false;

  // --- Logout ---

  Future<void> logout() async {
    try {
      await _repo.logout();
    } catch (e) {
      print('Local logout error: $e');
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('Connection refused') || msg.contains('SocketException')) {
      return 'Cannot reach the server. Please ensure the backend is running and you are connected to the same network.';
    }
    if (msg.contains('Exception:')) {
      return msg.replaceFirst('Exception: ', '');
    }
    if (msg.contains('DioException')) {
      return 'Network error. Please check your internet connection.';
    }
    return msg;
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    repo: ref.read(authRepositoryProvider),
    storage: ref.read(storageServiceProvider),
    apiService: ref.read(apiServiceProvider),
  );
});

/// Convenience provider to quickly access current user
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authControllerProvider).user;
});
