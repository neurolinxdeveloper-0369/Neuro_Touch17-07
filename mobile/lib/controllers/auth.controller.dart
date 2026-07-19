import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user.model.dart';
import '../data/repositories/auth.repository.dart';
import '../data/services/storage_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
    bool? isMfaRequired,
    String? mfaTempToken,
    bool? isInitialized,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error ?? this.error,
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
  final GoogleSignIn _googleSignIn;

  AuthController({
    required AuthRepository repo,
    required StorageService storage,
  })  : _repo = repo,
        _storage = storage,
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
    state = state.copyWith(status: AuthStatus.loading, error: null);
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
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _repo.verifyOtpLogin(
        phone: phone,
        otp: otp,
        name: name,
      );
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
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        state =
            state.copyWith(status: AuthStatus.unauthenticated, error: null);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('Google auth failed: no ID token');

      final user = await _repo.googleAuth(idToken);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e, stack) {
      print('Google Sign-in Error: $e');
      print('Google Sign-in Stack: $stack');
      state = state.copyWith(
        status: AuthStatus.error,
        error: _parseError(e),
      );
    }
  }

  // --- Legacy Password Stubs (Obsolete) ---
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
    state = state.copyWith(error: null);
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
  );
});

/// Convenience provider to quickly access current user
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authControllerProvider).user;
});
