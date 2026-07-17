import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.model.dart';
import 'dart:convert';

class StorageService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _prefsBoxName = 'neuro_touch_prefs';
  static const _userKey = 'user_data';
  static const _homeIdKey = 'selected_home_id';
  static const _themeModeKey = 'theme_mode';

  final FlutterSecureStorage _secureStorage;
  late Box _prefsBox;

  StorageService._()
      : _secureStorage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  static final StorageService _instance = StorageService._();
  static StorageService get instance => _instance;

  static Future<void> init() async {
    await Hive.initFlutter();
    _instance._prefsBox = await Hive.openBox(_prefsBoxName);
  }

  // --- Tokens ---

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await Future.wait([
      _secureStorage.write(key: _accessTokenKey, value: accessToken),
      _secureStorage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() =>
      _secureStorage.read(key: _accessTokenKey);

  Future<String?> getRefreshToken() =>
      _secureStorage.read(key: _refreshTokenKey);

  Future<void> clearTokens() async {
    await Future.wait([
      _secureStorage.delete(key: _accessTokenKey),
      _secureStorage.delete(key: _refreshTokenKey),
    ]);
  }

  // --- User ---

  Future<void> saveUser(UserModel user) async {
    await _prefsBox.put(_userKey, jsonEncode(user.toJson()));
  }

  UserModel? getUser() {
    final raw = _prefsBox.get(_userKey) as String?;
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUser() => _prefsBox.delete(_userKey);

  // --- Home ---

  Future<void> saveHomeId(String homeId) =>
      _prefsBox.put(_homeIdKey, homeId);

  String? getHomeId() => _prefsBox.get(_homeIdKey) as String?;

  Future<void> clearHomeId() => _prefsBox.delete(_homeIdKey);

  // --- Theme ---

  Future<void> saveThemeMode(ThemeMode mode) =>
      _prefsBox.put(_themeModeKey, mode.index);

  ThemeMode getThemeMode() {
    final index = _prefsBox.get(_themeModeKey) as int?;
    if (index == null) return ThemeMode.system;
    return ThemeMode.values[index.clamp(0, ThemeMode.values.length - 1)];
  }

  // --- Clear All ---

  Future<void> clearAll() async {
    await Future.wait([
      clearTokens(),
      clearUser(),
      clearHomeId(),
    ]);
    await _prefsBox.clear();
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService.instance;
});
