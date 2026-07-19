import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../data/models/device.model.dart';
import '../data/models/floor.model.dart';
import '../data/models/room.model.dart';
import '../data/repositories/device.repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provisioning Step Enum
// ─────────────────────────────────────────────────────────────────────────────

enum ProvisionStep {
  /// User has selected a panel on the add-device screen
  panelSelected,

  /// Showing instructions (turn off mobile data, connect to hotspot)
  instructions,

  /// Waiting for user to confirm they've connected to the device hotspot
  awaitingHotspotConnection,

  /// Asking home network vs another network
  networkChoice,

  /// User typed a custom SSID/password
  customNetwork,

  /// HTTP POST in progress to 192.168.0.4/config
  sendingCredentials,

  /// Polling backend until ESP reports back with MAC
  waitingForDevice,

  /// User names the device
  naming,

  /// User chooses floor/room/site/outdoor assignment
  assigning,

  /// All done — device saved
  success,

  /// Something went wrong
  error,
}

// ─────────────────────────────────────────────────────────────────────────────
// Provisioning State
// ─────────────────────────────────────────────────────────────────────────────

class ProvisionState {
  final ProvisionStep step;
  final int panelNumber;        // 6, 7, or 8
  final String expectedSsid;   // e.g. Rollin_Lift_Panel_6
  final String tempDeviceId;   // nt-XXXXXXXX (pre-MAC)
  final String macAddress;     // AA:BB:CC:DD:EE:FF from ESP

  // Network
  final String? homeSsid;
  final String? homePassword;
  final String? customSsid;
  final String? customPassword;
  final bool useHomeNetwork;   // true = home network, false = custom

  // Assignment
  final String deviceName;
  final String assignmentType; // floor | room | site | outdoor
  final String? selectedFloorId;
  final String? selectedRoomId;
  final List<FloorModel> floors;
  final List<RoomModel> rooms;

  // Result
  final DeviceModel? provisionedDevice;
  final String? errorMessage;
  final bool isLoading;

  const ProvisionState({
    this.step = ProvisionStep.panelSelected,
    this.panelNumber = 6,
    this.expectedSsid = 'Rollin_Lift_Panel_6',
    this.tempDeviceId = '',
    this.macAddress = '',
    this.homeSsid,
    this.homePassword,
    this.customSsid,
    this.customPassword,
    this.useHomeNetwork = true,
    this.deviceName = '',
    this.assignmentType = 'room',
    this.selectedFloorId,
    this.selectedRoomId,
    this.floors = const [],
    this.rooms = const [],
    this.provisionedDevice,
    this.errorMessage,
    this.isLoading = false,
  });

  ProvisionState copyWith({
    ProvisionStep? step,
    int? panelNumber,
    String? expectedSsid,
    String? tempDeviceId,
    String? macAddress,
    String? homeSsid,
    String? homePassword,
    String? customSsid,
    String? customPassword,
    bool? useHomeNetwork,
    String? deviceName,
    String? assignmentType,
    String? selectedFloorId,
    String? selectedRoomId,
    List<FloorModel>? floors,
    List<RoomModel>? rooms,
    DeviceModel? provisionedDevice,
    String? errorMessage,
    bool? isLoading,
  }) {
    return ProvisionState(
      step: step ?? this.step,
      panelNumber: panelNumber ?? this.panelNumber,
      expectedSsid: expectedSsid ?? this.expectedSsid,
      tempDeviceId: tempDeviceId ?? this.tempDeviceId,
      macAddress: macAddress ?? this.macAddress,
      homeSsid: homeSsid ?? this.homeSsid,
      homePassword: homePassword ?? this.homePassword,
      customSsid: customSsid ?? this.customSsid,
      customPassword: customPassword ?? this.customPassword,
      useHomeNetwork: useHomeNetwork ?? this.useHomeNetwork,
      deviceName: deviceName ?? this.deviceName,
      assignmentType: assignmentType ?? this.assignmentType,
      selectedFloorId: selectedFloorId ?? this.selectedFloorId,
      selectedRoomId: selectedRoomId ?? this.selectedRoomId,
      floors: floors ?? this.floors,
      rooms: rooms ?? this.rooms,
      provisionedDevice: provisionedDevice ?? this.provisionedDevice,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provisioning Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ProvisionNotifier extends StateNotifier<ProvisionState> {
  final DeviceRepository _deviceRepo;
  final Ref _ref;

  Timer? _pollTimer;
  int _pollCount = 0;
  static const int _maxPollAttempts = 20; // 20 × 3s = 60s timeout

  ProvisionNotifier(this._deviceRepo, this._ref)
      : super(const ProvisionState());

  /// Returns expected SSID for a given panel number.
  static String ssidForPanel(int panelNumber) =>
      'Rollin_Lift_Panel_$panelNumber';

  /// Call this first when user selects a panel on the add-device screen.
  Future<void> initPanel(int panelNumber, String homeId) async {
    final ssid = ssidForPanel(panelNumber);

    state = ProvisionState(
      step: ProvisionStep.instructions,
      panelNumber: panelNumber,
      expectedSsid: ssid,
    );

    // Generate a temporary device ID from backend
    try {
      final tempId = await _deviceRepo.generateDeviceUuid();
      // Fetch home credentials in parallel
      final creds = await _deviceRepo.getHomeNetworkCredentials(homeId);
      // Fetch floors for assignment step
      final floors = await _deviceRepo.getHomeFloors(homeId);

      state = state.copyWith(
        tempDeviceId: tempId,
        homeSsid: creds['ssid'],
        homePassword: creds['password'],
        floors: floors,
      );
    } catch (_) {
      // Non-fatal — credentials can be entered manually
    }
  }

  /// User confirmed they've read instructions → go to hotspot prompt
  void confirmInstructions() {
    state = state.copyWith(step: ProvisionStep.awaitingHotspotConnection);
  }

  /// User says they've connected to the device hotspot → go to network choice
  void confirmHotspotConnected() {
    state = state.copyWith(step: ProvisionStep.networkChoice);
  }

  /// User chose to use the home network
  void selectHomeNetwork() {
    state = state.copyWith(
      useHomeNetwork: true,
      step: ProvisionStep.sendingCredentials,
    );
    _sendCredentialsToESP();
  }

  /// User chose to enter a custom network
  void selectCustomNetwork() {
    state = state.copyWith(
      useHomeNetwork: false,
      step: ProvisionStep.customNetwork,
    );
  }

  /// Called from custom network form when user confirms SSID + password
  void submitCustomNetwork(String ssid, String password) {
    state = state.copyWith(
      customSsid: ssid,
      customPassword: password,
      step: ProvisionStep.sendingCredentials,
    );
    _sendCredentialsToESP();
  }

  /// HTTP POST to ESP12F at 192.168.0.4/config
  Future<void> _sendCredentialsToESP() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final ssid = state.useHomeNetwork ? state.homeSsid : state.customSsid;
    final password =
        state.useHomeNetwork ? state.homePassword : state.customPassword;

    if (ssid == null || ssid.isEmpty) {
      state = state.copyWith(
        step: ProvisionStep.error,
        errorMessage: 'No Wi-Fi SSID available. Please enter network details.',
        isLoading: false,
      );
      return;
    }

    try {
      final url =
          Uri.parse('${ApiConstants.espApBaseUrl}${ApiConstants.espConfigEndpoint}');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'ssid': ssid,
              'password': password ?? '',
              'device_id': state.tempDeviceId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        state = state.copyWith(
          step: ProvisionStep.waitingForDevice,
          isLoading: false,
        );
        _startPollingForDevice();
      } else {
        state = state.copyWith(
          step: ProvisionStep.error,
          errorMessage:
              'Device rejected credentials (HTTP ${response.statusCode}). Check SSID and password.',
          isLoading: false,
        );
      }
    } on TimeoutException {
      state = state.copyWith(
        step: ProvisionStep.error,
        errorMessage:
            'Could not reach device at 192.168.0.4. Make sure you are connected to the device hotspot and mobile data is OFF.',
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        step: ProvisionStep.error,
        errorMessage: 'Failed to send credentials: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  /// Poll backend every 3s waiting for ESP to come online and report MAC
  void _startPollingForDevice() {
    _pollCount = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      _pollCount++;
      if (_pollCount > _maxPollAttempts) {
        _pollTimer?.cancel();
        state = state.copyWith(
          step: ProvisionStep.error,
          errorMessage:
              'Device did not come online within 60 seconds. Please retry.',
          isLoading: false,
        );
        return;
      }

      try {
        final resp = await _deviceRepo.checkProvisionStatus(state.tempDeviceId);
        if (resp == 'online') {
          _pollTimer?.cancel();
          // Assume MAC comes back from status endpoint (or read from response)
          // In this flow the ESP posts its MAC directly to the backend
          state = state.copyWith(
            step: ProvisionStep.naming,
            isLoading: false,
          );
        }
      } catch (_) {
        // Keep polling — transient network error
      }
    });
  }

  /// Called when ESP callback delivers the MAC address directly from firmware
  void onDeviceMacReceived(String mac) {
    _pollTimer?.cancel();
    state = state.copyWith(
      macAddress: mac,
      step: ProvisionStep.naming,
    );
  }

  /// User confirmed device name → go to assignment step
  void submitName(String name) {
    state = state.copyWith(
      deviceName: name,
      step: ProvisionStep.assigning,
    );
  }

  /// Update assignment type selection
  void setAssignmentType(String type) {
    state = state.copyWith(
      assignmentType: type,
      selectedFloorId: null,
      selectedRoomId: null,
    );
  }

  void setSelectedFloor(String floorId) async {
    state = state.copyWith(selectedFloorId: floorId, selectedRoomId: null);
    // Load rooms for this floor
    try {
      final rooms = await _deviceRepo.getFloorRooms(floorId);
      state = state.copyWith(rooms: rooms);
    } catch (_) {}
  }

  void setSelectedRoom(String roomId) {
    state = state.copyWith(selectedRoomId: roomId);
  }

  /// Final step — save device to backend
  Future<void> completeProvisioning(String homeId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Use MAC if available, else temp ID
      final deviceId =
          state.macAddress.isNotEmpty ? state.macAddress : state.tempDeviceId;

      final device = await _deviceRepo.provisionDevice(
        homeId: homeId,
        macAddress: deviceId,
        deviceType: 'touch_panel',
        name: state.deviceName,
        ssidPattern: state.expectedSsid,
        switchCount: state.panelNumber,
        assignmentType: state.assignmentType,
        floorId: state.selectedFloorId,
        roomId: state.selectedRoomId,
      );

      state = state.copyWith(
        step: ProvisionStep.success,
        provisionedDevice: device,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        step: ProvisionStep.error,
        errorMessage: 'Failed to save device: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  /// Go back to panel selection / reset
  void reset() {
    _pollTimer?.cancel();
    state = const ProvisionState();
  }

  /// Retry from error state — go back to network choice
  void retry() {
    _pollTimer?.cancel();
    state = state.copyWith(
      step: ProvisionStep.networkChoice,
      errorMessage: null,
      isLoading: false,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final provisionControllerProvider =
    StateNotifierProvider.autoDispose<ProvisionNotifier, ProvisionState>((ref) {
  final repo = ref.read(deviceRepositoryProvider);
  return ProvisionNotifier(repo, ref);
});
