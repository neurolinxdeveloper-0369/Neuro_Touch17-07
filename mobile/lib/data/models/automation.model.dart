import 'package:equatable/equatable.dart';

class AutomationCondition extends Equatable {
  final String type; // 'device_state' | 'time' | 'temperature'
  final String? deviceId;
  final int? switchIndex;
  final bool? expectedState;
  final String? cronExpr;
  final double? threshold;
  final String? comparison; // 'above' | 'below'

  const AutomationCondition({
    required this.type,
    this.deviceId,
    this.switchIndex,
    this.expectedState,
    this.cronExpr,
    this.threshold,
    this.comparison,
  });

  factory AutomationCondition.fromJson(Map<String, dynamic> json) =>
      AutomationCondition(
        type: json['type'] as String? ?? 'device_state',
        deviceId: json['device_id'] as String?,
        switchIndex: json['switch_index'] as int?,
        expectedState: json['expected_state'] as bool?,
        cronExpr: json['cron_expr'] as String?,
        threshold: (json['threshold'] as num?)?.toDouble(),
        comparison: json['comparison'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'device_id': deviceId,
        'switch_index': switchIndex,
        'expected_state': expectedState,
        'cron_expr': cronExpr,
        'threshold': threshold,
        'comparison': comparison,
      };

  @override
  List<Object?> get props => [
        type, deviceId, switchIndex, expectedState, cronExpr, threshold, comparison
      ];
}

class AutomationAction extends Equatable {
  final String type; // 'device_command' | 'notification'
  final String? deviceId;
  final int? switchIndex;
  final bool? command;
  final String? irButtonCode;
  final String? notificationTitle;
  final String? notificationBody;

  const AutomationAction({
    required this.type,
    this.deviceId,
    this.switchIndex,
    this.command,
    this.irButtonCode,
    this.notificationTitle,
    this.notificationBody,
  });

  factory AutomationAction.fromJson(Map<String, dynamic> json) =>
      AutomationAction(
        type: json['type'] as String? ?? 'device_command',
        deviceId: json['device_id'] as String?,
        switchIndex: json['switch_index'] as int?,
        command: json['command'] as bool?,
        irButtonCode: json['ir_button_code'] as String?,
        notificationTitle: json['notification_title'] as String?,
        notificationBody: json['notification_body'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'device_id': deviceId,
        'switch_index': switchIndex,
        'command': command,
        'ir_button_code': irButtonCode,
        'notification_title': notificationTitle,
        'notification_body': notificationBody,
      };

  @override
  List<Object?> get props => [
        type, deviceId, switchIndex, command, irButtonCode,
        notificationTitle, notificationBody
      ];
}

class AutomationModel extends Equatable {
  final String id;
  final String homeId;
  final String name;
  final List<AutomationCondition> conditions;
  final List<AutomationAction> actions;
  final bool isActive;
  final DateTime createdAt;

  const AutomationModel({
    required this.id,
    required this.homeId,
    required this.name,
    this.conditions = const [],
    this.actions = const [],
    this.isActive = true,
    required this.createdAt,
  });

  factory AutomationModel.fromJson(Map<String, dynamic> json) =>
      AutomationModel(
        id: json['id'] as String? ?? '',
        homeId: json['home_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        conditions: (json['conditions'] as List<dynamic>? ?? [])
            .map((c) =>
                AutomationCondition.fromJson(c as Map<String, dynamic>))
            .toList(),
        actions: (json['actions'] as List<dynamic>? ?? [])
            .map((a) => AutomationAction.fromJson(a as Map<String, dynamic>))
            .toList(),
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'home_id': homeId,
        'name': name,
        'conditions': conditions.map((c) => c.toJson()).toList(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  AutomationModel copyWith({
    String? id,
    String? homeId,
    String? name,
    List<AutomationCondition>? conditions,
    List<AutomationAction>? actions,
    bool? isActive,
    DateTime? createdAt,
  }) =>
      AutomationModel(
        id: id ?? this.id,
        homeId: homeId ?? this.homeId,
        name: name ?? this.name,
        conditions: conditions ?? this.conditions,
        actions: actions ?? this.actions,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props =>
      [id, homeId, name, conditions, actions, isActive, createdAt];
}

class ScheduleModel extends Equatable {
  final String id;
  final String deviceId;
  final int switchIndex;
  final String cronExpr;
  final String action; // 'on' | 'off'
  final bool isActive;
  final DateTime createdAt;

  const ScheduleModel({
    required this.id,
    required this.deviceId,
    required this.switchIndex,
    required this.cronExpr,
    required this.action,
    this.isActive = true,
    required this.createdAt,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) => ScheduleModel(
        id: json['id'] as String? ?? '',
        deviceId: json['device_id'] as String? ?? '',
        switchIndex: json['switch_index'] as int? ?? 1,
        cronExpr: json['cron_expr'] as String? ?? '0 8 * * *',
        action: json['action'] as String? ?? 'on',
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': deviceId,
        'switch_index': switchIndex,
        'cron_expr': cronExpr,
        'action': action,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  ScheduleModel copyWith({
    String? id,
    String? deviceId,
    int? switchIndex,
    String? cronExpr,
    String? action,
    bool? isActive,
    DateTime? createdAt,
  }) =>
      ScheduleModel(
        id: id ?? this.id,
        deviceId: deviceId ?? this.deviceId,
        switchIndex: switchIndex ?? this.switchIndex,
        cronExpr: cronExpr ?? this.cronExpr,
        action: action ?? this.action,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );

  /// Returns a human-readable description of the schedule
  String get humanReadable {
    final parts = cronExpr.split(' ');
    if (parts.length != 5) return cronExpr;

    final minute = parts[0];
    final hour = parts[1];
    final dayOfWeek = parts[4];

    String timeStr = '';
    try {
      final h = int.parse(hour);
      final m = int.parse(minute);
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      timeStr = '$h12:${m.toString().padLeft(2, '0')} $period';
    } catch (_) {
      timeStr = '$hour:$minute';
    }

    String dayStr = '';
    if (dayOfWeek == '*') {
      dayStr = 'Every day';
    } else {
      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      final dayNums = dayOfWeek.split(',').map((d) => int.tryParse(d)).whereType<int>();
      dayStr = dayNums.map((d) => d < days.length ? days[d] : '$d').join(', ');
    }

    return '$dayStr at $timeStr - Turn ${action.toUpperCase()}';
  }

  @override
  List<Object?> get props =>
      [id, deviceId, switchIndex, cronExpr, action, isActive, createdAt];
}

class ChatMessage extends Equatable {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? '',
        role: json['role'] as String? ?? 'user',
        content: json['content'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  @override
  List<Object?> get props => [id, role, content, timestamp];
}
