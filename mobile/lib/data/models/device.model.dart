import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum DeviceType {
  touchPanel,
  irBlaster,
  liftPanel,
  energyMeter,
  tempMonitor,
}

extension DeviceTypeExtension on DeviceType {
  String get displayName {
    switch (this) {
      case DeviceType.touchPanel:
        return 'Smart Touch Panel';
      case DeviceType.irBlaster:
        return 'IR Blaster';
      case DeviceType.liftPanel:
        return 'Lift Panel';
      case DeviceType.energyMeter:
        return 'Energy Meter';
      case DeviceType.tempMonitor:
        return 'Temp Monitor';
    }
  }

  String get shortName {
    switch (this) {
      case DeviceType.touchPanel:
        return 'Touch Panel';
      case DeviceType.irBlaster:
        return 'IR Blaster';
      case DeviceType.liftPanel:
        return 'Lift Panel';
      case DeviceType.energyMeter:
        return 'Energy Meter';
      case DeviceType.tempMonitor:
        return 'Temp Monitor';
    }
  }

  IconData get icon {
    switch (this) {
      case DeviceType.touchPanel:
        return Icons.grid_view_rounded;
      case DeviceType.irBlaster:
        return Icons.sensors_rounded;
      case DeviceType.liftPanel:
        return Icons.elevator_rounded;
      case DeviceType.energyMeter:
        return Icons.electric_bolt_rounded;
      case DeviceType.tempMonitor:
        return Icons.thermostat_rounded;
    }
  }

  Color get color {
    switch (this) {
      case DeviceType.touchPanel:
        return const Color(0xFF4C6FFF);
      case DeviceType.irBlaster:
        return const Color(0xFF6C5CE7);
      case DeviceType.liftPanel:
        return const Color(0xFFE17055);
      case DeviceType.energyMeter:
        return const Color(0xFF00B894);
      case DeviceType.tempMonitor:
        return const Color(0xFF00CEC9);
    }
  }

  String get apiValue {
    switch (this) {
      case DeviceType.touchPanel:
        return 'touch_panel';
      case DeviceType.irBlaster:
        return 'ir_blaster';
      case DeviceType.liftPanel:
        return 'lift_panel';
      case DeviceType.energyMeter:
        return 'energy_meter';
      case DeviceType.tempMonitor:
        return 'temp_monitor';
    }
  }

  static DeviceType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'touch_panel':
      case 'touchpanel':
        return DeviceType.touchPanel;
      case 'ir_blaster':
      case 'irblaster':
        return DeviceType.irBlaster;
      case 'lift_panel':
      case 'liftpanel':
        return DeviceType.liftPanel;
      case 'energy_meter':
      case 'energymeter':
        return DeviceType.energyMeter;
      case 'temp_monitor':
      case 'tempmonitor':
        return DeviceType.tempMonitor;
      default:
        return DeviceType.touchPanel;
    }
  }
}

class SwitchConfigModel extends Equatable {
  final String id;
  final String deviceId;
  final int switchIndex;
  final String name;
  final String icon;
  final String? shortcutType;

  const SwitchConfigModel({
    required this.id,
    required this.deviceId,
    required this.switchIndex,
    required this.name,
    this.icon = 'lightbulb',
    this.shortcutType,
  });

  factory SwitchConfigModel.fromJson(Map<String, dynamic> json) =>
      SwitchConfigModel(
        id: json['id']?.toString() ?? '',
        deviceId: json['device_id'] as String? ?? '',
        switchIndex: json['switch_index'] as int? ?? 1,
        name: json['name'] as String? ?? 'Switch',
        icon: json['icon'] as String? ?? 'lightbulb',
        shortcutType: json['shortcut_type'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': deviceId,
        'switch_index': switchIndex,
        'name': name,
        'icon': icon,
        'shortcut_type': shortcutType,
      };

  SwitchConfigModel copyWith({
    String? id,
    String? deviceId,
    int? switchIndex,
    String? name,
    String? icon,
    String? shortcutType,
  }) =>
      SwitchConfigModel(
        id: id ?? this.id,
        deviceId: deviceId ?? this.deviceId,
        switchIndex: switchIndex ?? this.switchIndex,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        shortcutType: shortcutType ?? this.shortcutType,
      );

  @override
  List<Object?> get props =>
      [id, deviceId, switchIndex, name, icon, shortcutType];
}

class DeviceModel extends Equatable {
  final String id;
  final String homeId;
  final String? roomId;
  final DeviceType deviceType;
  final String name;
  final String? ssidPattern;
  final String? firmwareVersion;
  final bool isOnline;
  final DateTime? lastSeen;
  final int switchCount;
  final Map<String, dynamic> config;
  final List<SwitchConfigModel> switches;

  const DeviceModel({
    required this.id,
    required this.homeId,
    this.roomId,
    required this.deviceType,
    required this.name,
    this.ssidPattern,
    this.firmwareVersion,
    this.isOnline = false,
    this.lastSeen,
    this.switchCount = 1,
    this.config = const {},
    this.switches = const [],
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
        id: json['id'] as String,
        homeId: json['home_id'] as String? ?? '',
        roomId: json['room_id'] as String?,
        deviceType:
            DeviceTypeExtension.fromString(json['device_type'] as String? ?? ''),
        name: json['name'] as String? ?? '',
        ssidPattern: json['ssid_pattern'] as String?,
        firmwareVersion: json['firmware_version'] as String?,
        isOnline: json['is_online'] as bool? ?? false,
        lastSeen: json['last_seen'] != null
            ? DateTime.tryParse(json['last_seen'] as String)
            : null,
        switchCount: json['switch_count'] as int? ?? 1,
        config: (json['config'] as Map<String, dynamic>?) ?? {},
        switches: (json['switches'] as List<dynamic>? ?? [])
            .map((s) => SwitchConfigModel.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'home_id': homeId,
        'room_id': roomId,
        'device_type': deviceType.apiValue,
        'name': name,
        'ssid_pattern': ssidPattern,
        'firmware_version': firmwareVersion,
        'is_online': isOnline,
        'last_seen': lastSeen?.toIso8601String(),
        'switch_count': switchCount,
        'config': config,
        'switches': switches.map((s) => s.toJson()).toList(),
      };

  DeviceModel copyWith({
    String? id,
    String? homeId,
    String? roomId,
    DeviceType? deviceType,
    String? name,
    String? ssidPattern,
    String? firmwareVersion,
    bool? isOnline,
    DateTime? lastSeen,
    int? switchCount,
    Map<String, dynamic>? config,
    List<SwitchConfigModel>? switches,
  }) =>
      DeviceModel(
        id: id ?? this.id,
        homeId: homeId ?? this.homeId,
        roomId: roomId ?? this.roomId,
        deviceType: deviceType ?? this.deviceType,
        name: name ?? this.name,
        ssidPattern: ssidPattern ?? this.ssidPattern,
        firmwareVersion: firmwareVersion ?? this.firmwareVersion,
        isOnline: isOnline ?? this.isOnline,
        lastSeen: lastSeen ?? this.lastSeen,
        switchCount: switchCount ?? this.switchCount,
        config: config ?? this.config,
        switches: switches ?? this.switches,
      );

  @override
  List<Object?> get props => [
        id, homeId, roomId, deviceType, name, ssidPattern,
        firmwareVersion, isOnline, lastSeen, switchCount, config
      ];
}
