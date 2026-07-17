class MqttConstants {
  MqttConstants._();

  static const String host = String.fromEnvironment(
    'MQTT_HOST',
    defaultValue: '192.168.1.100',
  );

  static const int port = 1883;

  static const String username = String.fromEnvironment(
    'MQTT_USER',
    defaultValue: 'neurotouch_app',
  );

  static const String password = String.fromEnvironment(
    'MQTT_PASS',
    defaultValue: '',
  );

  // --- Topic Builders ---

  static String deviceCommand(String deviceId, String feature) =>
      'neurotouch/devices/$deviceId/command/$feature';

  static String deviceTelemetry(String deviceId, String feature) =>
      'neurotouch/devices/$deviceId/telemetry/$feature';

  static String deviceStatus(String deviceId) =>
      'neurotouch/devices/$deviceId/status';

  static String deviceHeartbeat(String deviceId) =>
      'neurotouch/devices/$deviceId/heartbeat';

  static String homeBroadcast(String homeId) =>
      'neurotouch/homes/$homeId/broadcast';

  // --- Wildcard Subscriptions ---

  static const String allDevicesTelemetry = 'neurotouch/devices/+/telemetry/#';
  static const String allDevicesStatus = 'neurotouch/devices/+/status';
  static const String allDevicesHeartbeat = 'neurotouch/devices/+/heartbeat';
  static const String allDeviceCommands = 'neurotouch/devices/+/command/#';

  // --- QoS Levels ---
  static const int qosTelemetry = 0; // fire and forget
  static const int qosCommand = 1; // at least once
  static const int qosHeartbeat = 1; // at least once
  static const int qosStatus = 1; // at least once
}
