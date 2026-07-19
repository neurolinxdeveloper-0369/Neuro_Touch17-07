class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.100:8080/api/v1',
  );

  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;

  // --- Auth ---
  static const String googleAuth = '/auth/google';
  static const String sendOtp = '/auth/otp/send';
  static const String verifyOtpLogin = '/auth/otp/verify';
  static const String refreshToken = '/auth/refresh-token';

  // --- Homes ---
  static const String homes = '/homes';
  static String homeById(String id) => '/homes/$id';
  static String homeInvite(String id) => '/homes/$id/invite';
  static const String joinHome = '/homes/join';
  static String homeMembers(String homeId) => '/homes/$homeId/members';
  static String homeMember(String homeId, String userId) =>
      '/homes/$homeId/members/$userId';

  // --- Network Credentials (for ESP provisioning) ---
  static String homeNetworkCredentials(String homeId) =>
      '/homes/$homeId/network-credentials';

  // --- Floors & Rooms ---
  static String homeFloors(String homeId) => '/homes/$homeId/floors';
  static String floorRooms(String floorId) => '/floors/$floorId/rooms';

  // --- Devices ---
  static String homeDevices(String homeId) => '/homes/$homeId/devices';
  static String device(String id) => '/devices/$id';
  static String deviceCommand(String id) => '/devices/$id/command';
  static String deviceSwitches(String id) => '/devices/$id/switches';
  static String deviceSwitch(String id, int index) =>
      '/devices/$id/switches/$index';
  static String irProfiles(String id) => '/devices/$id/ir-profiles';

  // --- Telemetry ---
  static String telemetryLatest(String deviceId) =>
      '/devices/$deviceId/telemetry/latest';
  static String telemetryHistory(String deviceId) =>
      '/devices/$deviceId/telemetry/history';

  // --- Automations ---
  static String homeAutomations(String homeId) =>
      '/homes/$homeId/automations';
  static String automation(String id) => '/automations/$id';
  static String toggleAutomation(String id) => '/automations/$id/toggle';

  // --- Schedules ---
  static String deviceSchedules(String deviceId) =>
      '/devices/$deviceId/schedules';
  static String schedule(String id) => '/schedules/$id';

  // --- Notifications ---
  static const String notifications = '/notifications';
  static String notification(String id) => '/notifications/$id';

  // --- AI ---
  static const String aiChat = '/ai/chat';

  // --- Provisioning ---
  static const String generateUuid = '/provision/generate-uuid';
  static const String validatePanel = '/provision/validate-panel';
  static String provisionStatus(String deviceId) =>
      '/provision/$deviceId/status';
  static const String provisionDevice = '/provision/device';

  // --- ESP12F Device AP (SoftAP direct connection) ---
  /// Fixed IP of the ESP12F in AP mode — only reachable when phone is on device hotspot
  static const String espApBaseUrl = 'http://192.168.0.4';
  static const String espConfigEndpoint = '/config';
}
