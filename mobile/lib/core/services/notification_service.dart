import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String alarmChannelKey = 'critical_alarm_channel';

  Future<void> initialize() async {
    // 1. Initialize Awesome Notifications
    await AwesomeNotifications().initialize(
      null, // default icon
      [
        NotificationChannel(
          channelGroupKey: 'alarm_group',
          channelKey: alarmChannelKey,
          channelName: 'Critical Alarms',
          channelDescription: 'High priority alarms for device thresholds',
          defaultColor: const Color(0xFFFF5252),
          ledColor: Colors.red,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          locked: true, // Cannot be swiped away easily
          criticalAlerts: true, // iOS bypass mute switch
          defaultRingtoneType: DefaultRingtoneType.Alarm,
          playSound: true,
          enableVibration: true,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: 'alarm_group',
          channelGroupName: 'Alarms',
        )
      ],
      debug: true,
    );

    // 2. Request permissions
    await requestPermissions();

    // 3. Set up listeners
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );

    // 4. Set up FCM Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. Handle FCM Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _triggerAlarmFromMessage(message);
    });
  }

  Future<void> requestPermissions() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications(
        channelList: [alarmChannelKey],
        permissions: [
          NotificationPermission.Alert,
          NotificationPermission.Sound,
          NotificationPermission.Badge,
          NotificationPermission.Vibration,
          NotificationPermission.Light,
          NotificationPermission.CriticalAlert,
          NotificationPermission.FullScreenIntent,
        ],
      );
    }
  }
  
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(); // Ensure firebase is initialized
    _triggerAlarmFromMessage(message);
  }

  static void _triggerAlarmFromMessage(RemoteMessage message) {
    if (message.data['is_alarm'] == 'true') {
      final deviceId = message.data['device_id'] ?? 'Unknown';
      final roomName = message.data['room_name'] ?? 'Unknown Room';
      final temperature = message.data['temperature'] ?? 'N/A';
      
      triggerCriticalAlarm(deviceId: deviceId, roomName: roomName, temperature: temperature);
    }
  }

  static void triggerCriticalAlarm({
    required String deviceId,
    required String roomName,
    required String temperature,
  }) {
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: deviceId.hashCode,
        channelKey: alarmChannelKey,
        title: 'CRITICAL ALERT: $roomName',
        body: 'Temperature exceeded threshold! Current: $temperature°C',
        category: NotificationCategory.Alarm,
        wakeUpScreen: true,
        fullScreenIntent: true,
        criticalAlert: true,
        autoDismissible: false,
        payload: {
          'device_id': deviceId,
          'room_name': roomName,
          'temperature': temperature,
          'route': '/alarm',
        },
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'DISMISS',
          label: 'DISMISS ALARM',
          actionType: ActionType.Default,
          isDangerousOption: true,
        )
      ],
    );
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    // We will navigate to the custom AlarmScreen
    // Since this runs in isolate, we might rely on GoRouter or standard stream.
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {}

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {}

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {}
}
