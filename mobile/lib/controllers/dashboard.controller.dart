import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/device.model.dart';
import '../data/repositories/device.repository.dart';
import '../data/repositories/home.repository.dart';
import '../data/services/storage_service.dart';

class ShortcutItem {
  final String id;
  final String deviceId;
  final int switchIndex;
  final String name;
  final String icon;
  final String colorHex;

  const ShortcutItem({
    required this.id,
    required this.deviceId,
    required this.switchIndex,
    required this.name,
    this.icon = 'lightbulb',
    this.colorHex = '#4C6FFF',
  });

  factory ShortcutItem.fromJson(Map<String, dynamic> json) => ShortcutItem(
        id: json['id'] as String,
        deviceId: json['device_id'] as String,
        switchIndex: json['switch_index'] as int? ?? 1,
        name: json['name'] as String? ?? 'Shortcut',
        icon: json['icon'] as String? ?? 'lightbulb',
        colorHex: json['color_hex'] as String? ?? '#4C6FFF',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': deviceId,
        'switch_index': switchIndex,
        'name': name,
        'icon': icon,
        'color_hex': colorHex,
      };
}

class DashboardState {
  final List<DeviceModel> devices;
  final List<ShortcutItem> shortcuts;
  final int notificationCount;
  final bool isLoading;
  final String? error;

  const DashboardState({
    this.devices = const [],
    this.shortcuts = const [],
    this.notificationCount = 0,
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    List<DeviceModel>? devices,
    List<ShortcutItem>? shortcuts,
    int? notificationCount,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      DashboardState(
        devices: devices ?? this.devices,
        shortcuts: shortcuts ?? this.shortcuts,
        notificationCount: notificationCount ?? this.notificationCount,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

class DashboardController extends StateNotifier<DashboardState> {
  final DeviceRepository _deviceRepo;

  DashboardController({required DeviceRepository deviceRepo})
      : _deviceRepo = deviceRepo,
        super(const DashboardState());

  Future<void> loadDashboard(String homeId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final devices = await _deviceRepo.getHomeDevices(homeId);
      state = state.copyWith(
        devices: devices,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> refreshDevices(String homeId) async {
    try {
      final devices = await _deviceRepo.getHomeDevices(homeId);
      state = state.copyWith(devices: devices);
    } catch (_) {}
  }

  void addShortcut(ShortcutItem item) {
    if (state.shortcuts.any((s) => s.id == item.id)) return;
    state = state.copyWith(shortcuts: [...state.shortcuts, item]);
  }

  void removeShortcut(String id) {
    state = state.copyWith(
      shortcuts: state.shortcuts.where((s) => s.id != id).toList(),
    );
  }

  void updateNotificationCount(int count) {
    state = state.copyWith(notificationCount: count);
  }

  /// Update a device's online status locally (from MQTT heartbeat)
  void updateDeviceStatus(String deviceId, bool isOnline) {
    final updated = state.devices.map((d) {
      if (d.id == deviceId) return d.copyWith(isOnline: isOnline);
      return d;
    }).toList();
    state = state.copyWith(devices: updated);
  }

  void clearError() => state = state.copyWith(clearError: true);
}

/// Stores the selected/active home id
final homeIdProvider = StateProvider<String?>((ref) {
  return ref.read(storageServiceProvider).getHomeId();
});

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>((ref) {
  return DashboardController(
    deviceRepo: ref.read(deviceRepositoryProvider),
  );
});
