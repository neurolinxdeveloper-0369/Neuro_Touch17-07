import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.model.dart';
import '../models/floor.model.dart';
import '../models/room.model.dart';
import '../models/telemetry.model.dart';
import '../services/api_client.dart';
import '../../core/constants/api_constants.dart';

class DeviceRepository {
  final ApiClient _api;

  DeviceRepository({required ApiClient api}) : _api = api;

  // ─── Devices ──────────────────────────────────────────────

  Future<List<DeviceModel>> getHomeDevices(String homeId) async {
    print('DEBUG: Fetching devices for homeId: $homeId');
    try {
      final resp = await _api.get(ApiConstants.homeDevices(homeId));
      print('DEBUG: API Response status: ${resp.statusCode}');
      print('DEBUG: API Response data: ${resp.data}');
      
      final data = resp.data as Map<String, dynamic>;
      if (data['success'] != true) throw Exception(data['error']);
      
      final rawDevices = data['devices'] as List<dynamic>;
      print('DEBUG: Found ${rawDevices.length} raw devices');
      
      final parsed = rawDevices
          .map((d) {
            print('DEBUG: Parsing device: $d');
            return DeviceModel.fromJson(d as Map<String, dynamic>);
          })
          .toList();
      print('DEBUG: Successfully parsed ${parsed.length} devices');
      return parsed;
    } catch (e, stackTrace) {
      print('DEBUG: getHomeDevices ERROR: $e');
      print('DEBUG: StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<DeviceModel> getDevice(String deviceId) async {
    final resp = await _api.get(ApiConstants.device(deviceId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return DeviceModel.fromJson(data['device'] as Map<String, dynamic>);
  }

  Future<DeviceModel> updateDevice(
    String deviceId, {
    String? name,
    String? roomId,
    Map<String, dynamic>? config,
  }) async {
    final resp = await _api.put(ApiConstants.device(deviceId), data: {
      if (name != null) 'name': name,
      if (roomId != null) 'room_id': roomId,
      if (config != null) 'config': config,
    });
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return DeviceModel.fromJson(data['device'] as Map<String, dynamic>);
  }

  Future<void> deleteDevice(String deviceId) async {
    final resp = await _api.delete(ApiConstants.device(deviceId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
  }

  Future<void> sendCommand(
    String deviceId,
    String feature,
    Map<String, dynamic> payload,
  ) async {
    await _api.post(ApiConstants.deviceCommand(deviceId), data: {
      'feature': feature,
      'payload': payload,
    });
  }

  // ─── Switches ──────────────────────────────────────────────

  Future<List<SwitchConfigModel>> getSwitches(String deviceId) async {
    final resp = await _api.get(ApiConstants.deviceSwitches(deviceId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return (data['switches'] as List<dynamic>)
        .map((s) => SwitchConfigModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<SwitchConfigModel> updateSwitch(
    String deviceId,
    int switchIndex, {
    String? name,
    String? icon,
    String? shortcutType,
  }) async {
    final resp = await _api.put(
      ApiConstants.deviceSwitch(deviceId, switchIndex),
      data: {
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
        if (shortcutType != null) 'shortcut_type': shortcutType,
      },
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return SwitchConfigModel.fromJson(data['switch'] as Map<String, dynamic>);
  }

  // ─── IR Profiles ──────────────────────────────────────────

  Future<Map<String, dynamic>> getIRProfiles(
    String deviceId,
    String applianceType,
  ) async {
    final resp = await _api.get(
      ApiConstants.irProfiles(deviceId),
      queryParameters: {'appliance_type': applianceType},
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return data;
  }

  // ─── Telemetry ──────────────────────────────────────────────

  Future<Map<String, TelemetryModel>> getLatestTelemetry(
      String deviceId) async {
    final resp = await _api.get(ApiConstants.telemetryLatest(deviceId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    final points = data['telemetry'] as Map<String, dynamic>? ?? {};
    return points.map((key, value) => MapEntry(
          key,
          TelemetryModel.fromJson(value as Map<String, dynamic>),
        ));
  }

  Future<TelemetryHistoryModel> getTelemetryHistory(
    String deviceId,
    String metric, {
    String resolution = 'hourly',
    DateTime? from,
    DateTime? to,
  }) async {
    final resp = await _api.get(
      ApiConstants.telemetryHistory(deviceId),
      queryParameters: {
        'metric': metric,
        'resolution': resolution,
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      },
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return TelemetryHistoryModel.fromJson(data['history'] as Map<String, dynamic>);
  }

  // ─── Floors & Rooms ──────────────────────────────────────────────

  Future<List<FloorModel>> getHomeFloors(String homeId) async {
    final resp = await _api.get(ApiConstants.homeFloors(homeId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return (data['floors'] as List<dynamic>)
        .map((f) => FloorModel.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  Future<List<RoomModel>> getFloorRooms(String floorId) async {
    final resp = await _api.get(ApiConstants.floorRooms(floorId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return (data['rooms'] as List<dynamic>)
        .map((r) => RoomModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ─── Provisioning ──────────────────────────────────────────────

  Future<String> generateDeviceUuid() async {
    final resp = await _api.post(ApiConstants.generateUuid);
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return data['device_id'] as String;
  }

  Future<String> checkProvisionStatus(String deviceId) async {
    final resp = await _api.get(ApiConstants.provisionStatus(deviceId));
    final data = resp.data as Map<String, dynamic>;
    return data['status'] as String? ?? 'pending';
  }

  Future<Map<String, String?>> getHomeNetworkCredentials(String homeId) async {
    final resp =
        await _api.get(ApiConstants.homeNetworkCredentials(homeId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return {
      'ssid': data['network_ssid'] as String?,
      'password': data['network_password'] as String?,
    };
  }

  Future<DeviceModel> provisionDevice({
    required String homeId,
    required String macAddress,
    required String deviceType,
    required String name,
    required String ssidPattern,
    required int switchCount,
    required String assignmentType,
    String? floorId,
    String? roomId,
  }) async {
    final resp = await _api.post(ApiConstants.provisionDevice, data: {
      'home_id': homeId,
      'mac_address': macAddress,
      'device_id': macAddress, // use MAC as permanent ID
      'device_type': deviceType,
      'name': name,
      'ssid_pattern': ssidPattern,
      'switch_count': switchCount,
      'assignment_type': assignmentType,
      if (floorId != null) 'floor_id': floorId,
      if (roomId != null) 'room_id': roomId,
    });
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return DeviceModel.fromJson(data['device'] as Map<String, dynamic>);
  }
}

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(api: ref.read(apiClientProvider));
});
