import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/mqtt_service.dart';
import '../core/constants/mqtt_constants.dart';

class MqttState {
  /// deviceId -> feature -> key -> value
  final Map<String, Map<String, Map<String, dynamic>>> deviceFeatures;

  /// deviceId -> isOnline
  final Map<String, bool> onlineMap;

  /// deviceId -> last heartbeat time
  final Map<String, DateTime> lastSeenMap;

  final bool isConnected;
  final MqttConnectionStatus connectionStatus;

  const MqttState({
    this.deviceFeatures = const {},
    this.onlineMap = const {},
    this.lastSeenMap = const {},
    this.isConnected = false,
    this.connectionStatus = MqttConnectionStatus.disconnected,
  });

  MqttState copyWith({
    Map<String, Map<String, Map<String, dynamic>>>? deviceFeatures,
    Map<String, bool>? onlineMap,
    Map<String, DateTime>? lastSeenMap,
    bool? isConnected,
    MqttConnectionStatus? connectionStatus,
  }) =>
      MqttState(
        deviceFeatures: deviceFeatures ?? this.deviceFeatures,
        onlineMap: onlineMap ?? this.onlineMap,
        lastSeenMap: lastSeenMap ?? this.lastSeenMap,
        isConnected: isConnected ?? this.isConnected,
        connectionStatus: connectionStatus ?? this.connectionStatus,
      );

  bool isDeviceOnline(String deviceId) => onlineMap[deviceId] ?? false;

  dynamic getDeviceValue(String deviceId, String feature, String key) {
    return deviceFeatures[deviceId]?[feature]?[key];
  }

  Map<String, dynamic> getFeatureMap(String deviceId, String feature) {
    return deviceFeatures[deviceId]?[feature] ?? {};
  }

  /// Get power reading for energy devices
  double getWatts(String deviceId) {
    return (deviceFeatures[deviceId]?['energy']?['power'] as num?)
            ?.toDouble() ??
        0.0;
  }

  double getTemperature(String deviceId) {
    return (deviceFeatures[deviceId]?['temperature']?['temperature'] as num?)
            ?.toDouble() ??
        0.0;
  }
}

class MqttController extends StateNotifier<MqttState> {
  final MqttService _mqttService;
  StreamSubscription<MqttMessage>? _msgSub;
  StreamSubscription<MqttConnectionStatus>? _statusSub;
  Timer? _heartbeatChecker;

  MqttController({required MqttService mqttService})
      : _mqttService = mqttService,
        super(const MqttState());

  Future<void> connect() async {
    _statusSub = _mqttService.statusStream.listen(_handleStatusChange);
    _msgSub = _mqttService.messageStream.listen(_handleMessage);

    await _mqttService.connect();

    _heartbeatChecker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkHeartbeats(),
    );
  }

  void _handleStatusChange(MqttConnectionStatus status) {
    state = state.copyWith(
      connectionStatus: status,
      isConnected: status == MqttConnectionStatus.connected,
    );
  }

  void _handleMessage(MqttMessage msg) {
    final parts = msg.topic.split('/');
    // Topic: nt/v1/{deviceId}/{direction}/{action}
    if (parts.length < 4 || parts[0] != 'nt' || parts[1] != 'v1') return;

    final deviceId = parts[2];
    final direction = parts[3];

    // Update last seen for ANY message from device
    _updateLastSeen(deviceId);

    if (direction == 'lwt') {
      _handleDeviceStatus(deviceId, msg.payload);
      return;
    }

    if (parts.length >= 5 && direction == 'stat') {
      final action = parts[4];
      if (action == 'state') {
        _handleStateUpdate(deviceId, msg.payload);
      } else if (action == 'telemetry') {
        _handleTelemetry(deviceId, 'telemetry', msg.payload);
      }
    }
  }

  void _updateLastSeen(String deviceId) {
    final newOnline = Map<String, bool>.from(state.onlineMap);
    final newLastSeen = Map<String, DateTime>.from(state.lastSeenMap);
    newOnline[deviceId] = true;
    newLastSeen[deviceId] = DateTime.now();
    state = state.copyWith(onlineMap: newOnline, lastSeenMap: newLastSeen);
  }

  void _handleStateUpdate(String deviceId, Map<String, dynamic> payload) {
    if (!payload.containsKey('switches')) return;
    
    // Convert 'switches' sub-object to expected format
    final Map<String, dynamic> switchesMap = Map<String, dynamic>.from(payload['switches']);
    final Map<String, dynamic> formattedSwitches = {};
    switchesMap.forEach((key, value) {
      formattedSwitches['sw$key'] = value;
    });
    
    // Deep clone
    final newFeatures =
        Map<String, Map<String, Map<String, dynamic>>>.from(state.deviceFeatures
            .map((k, v) => MapEntry(k, Map<String, Map<String, dynamic>>.from(
                v.map((k2, v2) => MapEntry(k2, Map<String, dynamic>.from(v2)))))));

    newFeatures[deviceId] ??= {};
    newFeatures[deviceId]!['switch'] = formattedSwitches;

    state = state.copyWith(deviceFeatures: newFeatures);
  }

  void _handleDeviceStatus(String deviceId, Map<String, dynamic> payload) {
    final isOnline = payload['status'] == 'online';
    final newOnline = Map<String, bool>.from(state.onlineMap);
    newOnline[deviceId] = isOnline;
    state = state.copyWith(onlineMap: newOnline);
  }

  void _handleTelemetry(
      String deviceId, String feature, Map<String, dynamic> payload) {
    // Deep clone
    final newFeatures =
        Map<String, Map<String, Map<String, dynamic>>>.from(state.deviceFeatures
            .map((k, v) => MapEntry(k, Map<String, Map<String, dynamic>>.from(
                v.map((k2, v2) => MapEntry(k2, Map<String, dynamic>.from(v2)))))));

    newFeatures[deviceId] ??= {};
    newFeatures[deviceId]![feature] = {
      ...newFeatures[deviceId]![feature] ?? {},
      ...payload,
    };

    state = state.copyWith(deviceFeatures: newFeatures);
  }

  void _checkHeartbeats() {
    final threshold = DateTime.now().subtract(const Duration(seconds: 60));
    final newOnline = Map<String, bool>.from(state.onlineMap);
    bool changed = false;

    for (final entry in state.lastSeenMap.entries) {
      if (entry.value.isBefore(threshold)) {
        if (newOnline[entry.key] != false) {
          newOnline[entry.key] = false;
          changed = true;
        }
      }
    }

    if (changed) state = state.copyWith(onlineMap: newOnline);
  }

  void publishCommand(
    String deviceId,
    String feature,
    Map<String, dynamic> payload,
  ) {
    _mqttService.publish(
      MqttConstants.deviceCommand(deviceId, feature),
      payload,
    );
  }

  void publishSwitchCommand(String deviceId, int switchIndex, bool stateValue) {
    // Optimistic UI update
    final currentValues = state.deviceFeatures[deviceId] ?? {};
    final currentFeatureValues = currentValues['switch'] ?? {};
    final newFeatureValues = Map<String, dynamic>.from(currentFeatureValues);
    newFeatureValues['sw$switchIndex'] = stateValue;

    final newDeviceValues = Map<String, Map<String, dynamic>>.from(currentValues);
    newDeviceValues['switch'] = newFeatureValues;

    final newGlobalValues = Map<String, Map<String, Map<String, dynamic>>>.from(state.deviceFeatures);
    newGlobalValues[deviceId] = newDeviceValues;

    state = state.copyWith(deviceFeatures: newGlobalValues);

    // Send MQTT command with new architecture payload
    publishCommand(deviceId, 'state', {
      'msg_id': 'app-req-${DateTime.now().millisecondsSinceEpoch}',
      'switches': {
        switchIndex.toString(): stateValue
      }
    });
  }

  void publishIrCommand(
    String deviceId,
    String brand,
    String applianceType,
    String buttonCode,
  ) {
    publishCommand(deviceId, 'ir', {
      'button': buttonCode,
      'brand': brand,
      'appliance': applianceType,
    });
  }

  void publishLiftCommand(String deviceId, String command) {
    publishCommand(deviceId, 'lift', {'command': command});
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _statusSub?.cancel();
    _heartbeatChecker?.cancel();
    super.dispose();
  }
}

final mqttControllerProvider =
    StateNotifierProvider<MqttController, MqttState>((ref) {
  return MqttController(
    mqttService: ref.read(mqttServiceProvider),
  );
});

/// Per-device online status provider
final deviceOnlineProvider = Provider.family<bool, String>((ref, deviceId) {
  return ref.watch(mqttControllerProvider).isDeviceOnline(deviceId);
});

/// Per-device feature map provider
final deviceFeaturesProvider =
    Provider.family<Map<String, Map<String, dynamic>>, String>(
        (ref, deviceId) {
  return ref.watch(mqttControllerProvider).deviceFeatures[deviceId] ?? {};
});
