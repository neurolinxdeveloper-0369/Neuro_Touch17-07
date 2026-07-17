import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/device.model.dart';
import '../data/models/floor.model.dart';
import '../data/models/room.model.dart';
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
  final List<FloorModel> floors;
  final List<RoomModel> rooms;
  final List<DeviceModel> devices;
  final String? selectedFloorId;
  final String? selectedRoomId;
  final List<ShortcutItem> shortcuts;
  final int notificationCount;
  final bool isLoading;
  final String? error;

  const DashboardState({
    this.floors = const [],
    this.rooms = const [],
    this.devices = const [],
    this.selectedFloorId,
    this.selectedRoomId,
    this.shortcuts = const [],
    this.notificationCount = 0,
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    List<FloorModel>? floors,
    List<RoomModel>? rooms,
    List<DeviceModel>? devices,
    String? selectedFloorId,
    String? selectedRoomId,
    List<ShortcutItem>? shortcuts,
    int? notificationCount,
    bool? isLoading,
    String? error,
    bool clearSelectedFloor = false,
    bool clearSelectedRoom = false,
    bool clearError = false,
  }) =>
      DashboardState(
        floors: floors ?? this.floors,
        rooms: rooms ?? this.rooms,
        devices: devices ?? this.devices,
        selectedFloorId:
            clearSelectedFloor ? null : selectedFloorId ?? this.selectedFloorId,
        selectedRoomId:
            clearSelectedRoom ? null : selectedRoomId ?? this.selectedRoomId,
        shortcuts: shortcuts ?? this.shortcuts,
        notificationCount: notificationCount ?? this.notificationCount,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );

  /// Rooms belonging to selected floor (or all rooms)
  List<RoomModel> get filteredRooms {
    if (selectedFloorId == null) return rooms;
    return rooms.where((r) => r.floorId == selectedFloorId).toList();
  }

  /// Devices filtered by selected room (or all devices in selected floor's rooms)
  List<DeviceModel> get filteredDevices {
    if (selectedRoomId != null) {
      return devices.where((d) => d.roomId == selectedRoomId).toList();
    }
    if (selectedFloorId != null) {
      final floorRoomIds =
          filteredRooms.map((r) => r.id).toSet();
      return devices.where((d) => floorRoomIds.contains(d.roomId)).toList();
    }
    return devices;
  }

  List<DeviceModel> devicesInRoom(String roomId) =>
      devices.where((d) => d.roomId == roomId).toList();
}

class DashboardController extends StateNotifier<DashboardState> {
  final DeviceRepository _deviceRepo;
  final HomeRepository _homeRepo;

  DashboardController({
    required DeviceRepository deviceRepo,
    required HomeRepository homeRepo,
  })  : _deviceRepo = deviceRepo,
        _homeRepo = homeRepo,
        super(const DashboardState());

  Future<void> loadDashboard(String homeId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _homeRepo.getFloors(homeId),
        _homeRepo.getRooms(homeId),
        _deviceRepo.getHomeDevices(homeId),
      ]);

      state = state.copyWith(
        floors: results[0] as List<FloorModel>,
        rooms: results[1] as List<RoomModel>,
        devices: results[2] as List<DeviceModel>,
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

  void selectFloor(String? floorId) {
    if (floorId == state.selectedFloorId) {
      state = state.copyWith(clearSelectedFloor: true, clearSelectedRoom: true);
    } else {
      state = state.copyWith(
        selectedFloorId: floorId,
        clearSelectedRoom: true,
      );
    }
  }

  void selectRoom(String? roomId) {
    if (roomId == state.selectedRoomId) {
      state = state.copyWith(clearSelectedRoom: true);
    } else {
      state = state.copyWith(selectedRoomId: roomId);
    }
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

final homeIdProvider = StateProvider<String?>((ref) {
  return ref.read(storageServiceProvider).getHomeId();
});

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>((ref) {
  return DashboardController(
    deviceRepo: ref.read(deviceRepositoryProvider),
    homeRepo: ref.read(homeRepositoryProvider),
  );
});
