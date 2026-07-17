import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/automation.model.dart';
import '../services/api_client.dart';
import '../../core/constants/api_constants.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final bool isRead;
  final String? deviceId;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.isRead = false,
    this.deviceId,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        isRead: json['is_read'] as bool? ?? false,
        deviceId: json['device_id'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        userId: userId,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        deviceId: deviceId,
        createdAt: createdAt,
      );
}

class AutomationRepository {
  final ApiClient _api;

  AutomationRepository({required ApiClient api}) : _api = api;

  // --- Automations ---

  Future<List<AutomationModel>> getAutomations(String homeId) async {
    final resp = await _api.get(ApiConstants.homeAutomations(homeId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return (data['automations'] as List<dynamic>)
        .map((a) => AutomationModel.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<AutomationModel> createAutomation(AutomationModel automation) async {
    final resp = await _api.post(
      ApiConstants.homeAutomations(automation.homeId),
      data: automation.toJson(),
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return AutomationModel.fromJson(
        data['automation'] as Map<String, dynamic>);
  }

  Future<AutomationModel> updateAutomation(
    String id,
    AutomationModel automation,
  ) async {
    final resp = await _api.put(
      ApiConstants.automation(id),
      data: automation.toJson(),
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return AutomationModel.fromJson(
        data['automation'] as Map<String, dynamic>);
  }

  Future<void> deleteAutomation(String id) async {
    final resp = await _api.delete(ApiConstants.automation(id));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
  }

  Future<AutomationModel> toggleAutomation(String id) async {
    final resp = await _api.post(ApiConstants.toggleAutomation(id));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return AutomationModel.fromJson(
        data['automation'] as Map<String, dynamic>);
  }

  // --- Schedules ---

  Future<List<ScheduleModel>> getSchedules(String deviceId) async {
    final resp = await _api.get(ApiConstants.deviceSchedules(deviceId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return (data['schedules'] as List<dynamic>)
        .map((s) => ScheduleModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<ScheduleModel> createSchedule(ScheduleModel schedule) async {
    final resp = await _api.post(
      ApiConstants.deviceSchedules(schedule.deviceId),
      data: schedule.toJson(),
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return ScheduleModel.fromJson(data['schedule'] as Map<String, dynamic>);
  }

  Future<ScheduleModel> updateSchedule(String id, ScheduleModel schedule) async {
    final resp = await _api.put(
      ApiConstants.schedule(id),
      data: schedule.toJson(),
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return ScheduleModel.fromJson(data['schedule'] as Map<String, dynamic>);
  }

  Future<void> deleteSchedule(String id) async {
    final resp = await _api.delete(ApiConstants.schedule(id));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
  }

  // --- Notifications ---

  Future<List<NotificationModel>> getNotifications() async {
    final resp = await _api.get(ApiConstants.notifications);
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return (data['notifications'] as List<dynamic>)
        .map((n) => NotificationModel.fromJson(n as Map<String, dynamic>))
        .toList();
  }

  Future<void> markNotificationRead(String id) async {
    await _api.patch(ApiConstants.notification(id), data: {'is_read': true});
  }

  Future<void> markAllRead() async {
    await _api.post('${ApiConstants.notifications}/mark-all-read');
  }

  // --- AI Chat ---

  Future<String> sendChatMessage(
    String homeId,
    String message,
    List<ChatMessage> history,
  ) async {
    final resp = await _api.post(ApiConstants.aiChat, data: {
      'home_id': homeId,
      'message': message,
      'history': history.map((m) => m.toJson()).toList(),
    });
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return data['response'] as String? ?? 'Sorry, I could not process that.';
  }
}

final automationRepositoryProvider = Provider<AutomationRepository>((ref) {
  return AutomationRepository(api: ref.read(apiClientProvider));
});
