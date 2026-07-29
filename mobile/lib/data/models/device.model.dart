import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum DeviceType {
  smartSwitch,
  irRemote,
  energyMeter,
  tempMonitor,
  customTouchPanel,
  waterLevel,
  neuroSmartSwitch,
  gasControl,
}

extension DeviceTypeExtension on DeviceType {
  String get displayName {
    switch (this) {
      case DeviceType.smartSwitch:
        return 'Smart Touch Switch';
      case DeviceType.irRemote:
        return 'IR Remote';
      case DeviceType.energyMeter:
        return 'Energy Meter';
      case DeviceType.tempMonitor:
        return 'Temperature Monitor';
      case DeviceType.customTouchPanel:
        return 'Custom Touch Panel';
      case DeviceType.waterLevel:
        return 'Water Level Controller';
      case DeviceType.neuroSmartSwitch:
        return 'Neuro Smart Switch';
      case DeviceType.gasControl:
        return 'Gas Controller';
    }
  }

  String get shortName {
    switch (this) {
      case DeviceType.smartSwitch:
        return 'Smart Switch';
      case DeviceType.irRemote:
        return 'IR Remote';
      case DeviceType.energyMeter:
        return 'Energy Meter';
      case DeviceType.tempMonitor:
        return 'Temp Monitor';
      case DeviceType.customTouchPanel:
        return 'Touch Panel';
      case DeviceType.waterLevel:
        return 'Water Level';
      case DeviceType.neuroSmartSwitch:
        return 'Smart Switch';
      case DeviceType.gasControl:
        return 'Gas Control';
    }
  }

  IconData get icon {
    switch (this) {
      case DeviceType.smartSwitch:
      case DeviceType.neuroSmartSwitch:
      case DeviceType.customTouchPanel:
        return Icons.grid_view_rounded;
      case DeviceType.irRemote:
        return Icons.settings_remote_rounded;
      case DeviceType.energyMeter:
        return Icons.electric_bolt_rounded;
      case DeviceType.tempMonitor:
        return Icons.thermostat_rounded;
      case DeviceType.waterLevel:
        return Icons.water_drop_rounded;
      case DeviceType.gasControl:
        return Icons.local_fire_department_rounded;
    }
  }

  Color get color {
    switch (this) {
      case DeviceType.smartSwitch:
      case DeviceType.neuroSmartSwitch:
      case DeviceType.customTouchPanel:
        return const Color(0xFF4C6FFF);
      case DeviceType.irRemote:
        return const Color(0xFF6C5CE7);
      case DeviceType.energyMeter:
        return const Color(0xFF00B894);
      case DeviceType.tempMonitor:
        return const Color(0xFF00CEC9);
      case DeviceType.waterLevel:
        return const Color(0xFF0984E3);
      case DeviceType.gasControl:
        return const Color(0xFFFF7675);
    }
  }

  String get apiValue {
    switch (this) {
      case DeviceType.smartSwitch:
        return 'smart_switch';
      case DeviceType.irRemote:
        return 'ir_remote';
      case DeviceType.energyMeter:
        return 'energy_meter';
      case DeviceType.tempMonitor:
        return 'temp_monitor';
      case DeviceType.customTouchPanel:
        return 'custom_touch_panel';
      case DeviceType.waterLevel:
        return 'water_level';
      case DeviceType.neuroSmartSwitch:
        return 'neuro_smart_switch';
      case DeviceType.gasControl:
        return 'gas_control';
    }
  }

  static DeviceType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'smart_switch':
      case 'smartswitch':
        return DeviceType.smartSwitch;
      case 'ir_remote':
      case 'irremote':
      case 'ir_blaster':
      case 'irblaster':
        return DeviceType.irRemote;
      case 'energy_meter':
      case 'energymeter':
        return DeviceType.energyMeter;
      case 'temp_monitor':
      case 'tempmonitor':
        return DeviceType.tempMonitor;
      case 'custom_touch_panel':
      case 'touch_panel':
      case 'lift_panel':
      case 'liftpanel':
        return DeviceType.customTouchPanel;
      case 'water_level':
      case 'waterlevel':
        return DeviceType.waterLevel;
      case 'neuro_smart_switch':
      case 'neurosmartswitch':
        return DeviceType.neuroSmartSwitch;
      case 'gas_control':
      case 'gascontrol':
        return DeviceType.gasControl;
      default:
        return DeviceType.smartSwitch;
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
  final DeviceType deviceType;
  final String name;
  final String? macAddress;
  final String? ssidPattern;
  final String? firmwareVersion;
  final bool isOnline;
  final DateTime? lastSeen;
  final int switchCount;
  final Map<String, dynamic> config;
  final List<SwitchConfigModel> switches;
  final String assignmentType; // floor | room | site | outdoor
  final String? floorId;
  final String? roomId;

  const DeviceModel({
    required this.id,
    required this.homeId,
    required this.deviceType,
    required this.name,
    this.macAddress,
    this.ssidPattern,
    this.firmwareVersion,
    this.isOnline = false,
    this.lastSeen,
    this.switchCount = 1,
    this.config = const {},
    this.switches = const [],
    this.assignmentType = 'room',
    this.floorId,
    this.roomId,
  });

  static Map<String, dynamic> _parseConfigString(dynamic configData) {
    if (configData is Map<String, dynamic>) {
      return configData;
    }
    if (configData is String) {
      try {
        final decoded = jsonDecode(configData);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
        id: json['id'] as String,
        homeId: json['home_id'] as String? ?? '',
        deviceType:
            DeviceTypeExtension.fromString(json['device_type'] as String? ?? ''),
        name: json['name'] as String? ?? '',
        macAddress: json['mac_address'] as String?,
        ssidPattern: json['ssid_pattern'] as String?,
        firmwareVersion: json['firmware_version'] as String?,
        isOnline: json['is_online'] as bool? ?? false,
        lastSeen: json['last_seen'] != null
            ? DateTime.tryParse(json['last_seen'] as String)
            : null,
        switchCount: json['switch_count'] as int? ?? 0,
        config: _parseConfigString(json['config']),
        switches: (json['switches'] as List<dynamic>? ?? [])
            .map((s) => SwitchConfigModel.fromJson(s as Map<String, dynamic>))
            .toList(),
        assignmentType: json['assignment_type'] as String? ?? 'room',
        floorId: json['floor_id'] as String?,
        roomId: json['room_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'home_id': homeId,
        'device_type': deviceType.apiValue,
        'name': name,
        'mac_address': macAddress,
        'ssid_pattern': ssidPattern,
        'firmware_version': firmwareVersion,
        'is_online': isOnline,
        'last_seen': lastSeen?.toIso8601String(),
        'switch_count': switchCount,
        'config': config,
        'switches': switches.map((s) => s.toJson()).toList(),
        'assignment_type': assignmentType,
        'floor_id': floorId,
        'room_id': roomId,
      };

  DeviceModel copyWith({
    String? id,
    String? homeId,
    DeviceType? deviceType,
    String? name,
    String? macAddress,
    String? ssidPattern,
    String? firmwareVersion,
    bool? isOnline,
    DateTime? lastSeen,
    int? switchCount,
    Map<String, dynamic>? config,
    List<SwitchConfigModel>? switches,
    String? assignmentType,
    String? floorId,
    String? roomId,
  }) =>
      DeviceModel(
        id: id ?? this.id,
        homeId: homeId ?? this.homeId,
        deviceType: deviceType ?? this.deviceType,
        name: name ?? this.name,
        macAddress: macAddress ?? this.macAddress,
        ssidPattern: ssidPattern ?? this.ssidPattern,
        firmwareVersion: firmwareVersion ?? this.firmwareVersion,
        isOnline: isOnline ?? this.isOnline,
        lastSeen: lastSeen ?? this.lastSeen,
        switchCount: switchCount ?? this.switchCount,
        config: config ?? this.config,
        switches: switches ?? this.switches,
        assignmentType: assignmentType ?? this.assignmentType,
        floorId: floorId ?? this.floorId,
        roomId: roomId ?? this.roomId,
      );

  @override
  List<Object?> get props => [
        id, homeId, deviceType, name, macAddress, ssidPattern,
        firmwareVersion, isOnline, lastSeen, switchCount, config,
        assignmentType, floorId, roomId,
      ];
}
