import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/mqtt_constants.dart';

enum MqttConnectionStatus { disconnected, connecting, connected, failed }

class MqttMessage {
  final String topic;
  final Map<String, dynamic> payload;
  final DateTime receivedAt;

  MqttMessage({
    required this.topic,
    required this.payload,
    required this.receivedAt,
  });
}

class MqttService {
  MqttServerClient? _client;
  final _messageController = StreamController<MqttMessage>.broadcast();
  final _statusController =
      StreamController<MqttConnectionStatus>.broadcast();

  MqttConnectionStatus _status = MqttConnectionStatus.disconnected;

  Stream<MqttMessage> get messageStream => _messageController.stream;
  Stream<MqttConnectionStatus> get statusStream => _statusController.stream;
  MqttConnectionStatus get status => _status;

  static final MqttService instance = MqttService._();
  MqttService._();

  void _setStatus(MqttConnectionStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  Future<void> connect() async {
    if (_status == MqttConnectionStatus.connected ||
        _status == MqttConnectionStatus.connecting) return;

    _setStatus(MqttConnectionStatus.connecting);

    final clientId =
        'neuro_touch_app_${const Uuid().v4().substring(0, 8)}';

    _client = MqttServerClient.withPort(
      MqttConstants.host,
      clientId,
      MqttConstants.port,
    )
      ..logging(on: false)
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..onConnected = _onConnected
      ..onDisconnected = _onDisconnected
      ..onAutoReconnect = _onAutoReconnect;

    _client!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(MqttConstants.username, MqttConstants.password)
        .withWillTopic('neurotouch/clients/$clientId/status')
        .withWillMessage('{"status":"offline"}')
        .withWillQos(MqttQos.atLeastOnce)
        .startClean();

    try {
      await _client!.connect();
    } catch (e) {
      _setStatus(MqttConnectionStatus.failed);
    }
  }

  void _onConnected() {
    _setStatus(MqttConnectionStatus.connected);

    // Subscribe to device topics
    _subscribe(MqttConstants.allDevicesTelemetry, MqttQos.atMostOnce);
    _subscribe(MqttConstants.allDevicesStatus, MqttQos.atLeastOnce);
    _subscribe(MqttConstants.allDevicesHeartbeat, MqttQos.atLeastOnce);

    // Listen to messages
    _client!.updates?.listen((events) {
      for (final event in events) {
        final topic = event.topic;
        final message = event.payload as MqttPublishMessage;
        final payloadStr =
            MqttPublishPayload.bytesToStringAsString(message.payload.message);

        try {
          final payload =
              jsonDecode(payloadStr) as Map<String, dynamic>;
          _messageController.add(MqttMessage(
            topic: topic,
            payload: payload,
            receivedAt: DateTime.now(),
          ));
        } catch (_) {
          // Non-JSON message — ignore
        }
      }
    });
  }

  void _onDisconnected() {
    if (_status != MqttConnectionStatus.connecting) {
      _setStatus(MqttConnectionStatus.disconnected);
    }
  }

  void _onAutoReconnect() {
    _setStatus(MqttConnectionStatus.connecting);
  }

  void _subscribe(String topic, MqttQos qos) {
    try {
      _client?.subscribe(topic, qos);
    } catch (_) {}
  }

  void publish(
    String topic,
    Map<String, dynamic> payload, {
    MqttQos qos = MqttQos.atLeastOnce,
    bool retain = false,
  }) {
    if (_status != MqttConnectionStatus.connected) return;

    final builder = MqttClientPayloadBuilder()
      ..addString(jsonEncode(payload));

    _client?.publishMessage(topic, qos, builder.payload!, retain: retain);
  }

  void disconnect() {
    _client?.disconnect();
    _setStatus(MqttConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _statusController.close();
  }
}

final mqttServiceProvider = Provider<MqttService>((ref) {
  final service = MqttService.instance;
  ref.onDispose(service.dispose);
  return service;
});
