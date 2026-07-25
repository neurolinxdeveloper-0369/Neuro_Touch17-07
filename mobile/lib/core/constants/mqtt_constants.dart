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

  // --- Topic Builders ---

  static String deviceCommand(String deviceId, String feature) =>
      'nt/v1/$deviceId/cmd/state'; // Using state as default command action

  static String deviceTelemetry(String deviceId, String feature) =>
      'nt/v1/$deviceId/stat/telemetry';

  static String deviceStatus(String deviceId) =>
      'nt/v1/$deviceId/stat/state'; // We now subscribe to stat/state for status

  static String deviceHeartbeat(String deviceId) =>
      'nt/v1/$deviceId/stat/telemetry'; // Heartbeat merged with telemetry

  static String deviceLWT(String deviceId) =>
      'nt/v1/$deviceId/lwt';

  static String homeBroadcast(String homeId) =>
      'nt/v1/homes/$homeId/broadcast';

  // --- Wildcard Subscriptions ---

  static const String allDevicesTelemetry = 'nt/v1/+/stat/telemetry';
  static const String allDevicesStatus = 'nt/v1/+/stat/state';
  static const String allDevicesHeartbeat = 'nt/v1/+/lwt';
  static const String allDeviceCommands = 'nt/v1/+/cmd/#';

  // --- QoS Levels ---
  static const int qosTelemetry = 0; // fire and forget
  static const int qosCommand = 1; // at least once
  static const int qosHeartbeat = 1; // at least once
  static const int qosStatus = 1; // at least once
}
