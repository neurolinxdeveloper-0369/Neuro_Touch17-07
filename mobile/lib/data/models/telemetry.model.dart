import 'package:equatable/equatable.dart';

enum TelemetryMetric {
  voltage,
  current,
  power,
  energy,
  powerFactor,
  temperature,
  humidity,
  switchState,
  liftFloor,
}

extension TelemetryMetricExtension on TelemetryMetric {
  String get apiKey {
    switch (this) {
      case TelemetryMetric.voltage: return 'voltage';
      case TelemetryMetric.current: return 'current';
      case TelemetryMetric.power: return 'power';
      case TelemetryMetric.energy: return 'energy';
      case TelemetryMetric.powerFactor: return 'power_factor';
      case TelemetryMetric.temperature: return 'temperature';
      case TelemetryMetric.humidity: return 'humidity';
      case TelemetryMetric.switchState: return 'switch_state';
      case TelemetryMetric.liftFloor: return 'lift_floor';
    }
  }

  String get displayName {
    switch (this) {
      case TelemetryMetric.voltage: return 'Voltage';
      case TelemetryMetric.current: return 'Current';
      case TelemetryMetric.power: return 'Power';
      case TelemetryMetric.energy: return 'Energy';
      case TelemetryMetric.powerFactor: return 'Power Factor';
      case TelemetryMetric.temperature: return 'Temperature';
      case TelemetryMetric.humidity: return 'Humidity';
      case TelemetryMetric.switchState: return 'Switch State';
      case TelemetryMetric.liftFloor: return 'Floor';
    }
  }

  String get unit {
    switch (this) {
      case TelemetryMetric.voltage: return 'V';
      case TelemetryMetric.current: return 'A';
      case TelemetryMetric.power: return 'W';
      case TelemetryMetric.energy: return 'kWh';
      case TelemetryMetric.powerFactor: return '';
      case TelemetryMetric.temperature: return '°C';
      case TelemetryMetric.humidity: return '%';
      case TelemetryMetric.switchState: return '';
      case TelemetryMetric.liftFloor: return '';
    }
  }

  static TelemetryMetric fromString(String value) {
    switch (value.toLowerCase()) {
      case 'voltage': return TelemetryMetric.voltage;
      case 'current': return TelemetryMetric.current;
      case 'power': return TelemetryMetric.power;
      case 'energy': return TelemetryMetric.energy;
      case 'power_factor': return TelemetryMetric.powerFactor;
      case 'temperature': return TelemetryMetric.temperature;
      case 'humidity': return TelemetryMetric.humidity;
      case 'switch_state': return TelemetryMetric.switchState;
      case 'lift_floor': return TelemetryMetric.liftFloor;
      default: return TelemetryMetric.power;
    }
  }
}

class TelemetryPoint extends Equatable {
  final DateTime timestamp;
  final double value;
  final double? avgValue;
  final double? minValue;
  final double? maxValue;

  const TelemetryPoint({
    required this.timestamp,
    required this.value,
    this.avgValue,
    this.minValue,
    this.maxValue,
  });

  factory TelemetryPoint.fromJson(Map<String, dynamic> json) => TelemetryPoint(
        timestamp: DateTime.parse(json['timestamp'] as String? ??
            json['recorded_at'] as String? ??
            DateTime.now().toIso8601String()),
        value: (json['value'] as num? ?? 0).toDouble(),
        avgValue: (json['avg_value'] as num?)?.toDouble(),
        minValue: (json['min_value'] as num?)?.toDouble(),
        maxValue: (json['max_value'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'value': value,
        'avg_value': avgValue,
        'min_value': minValue,
        'max_value': maxValue,
      };

  @override
  List<Object?> get props =>
      [timestamp, value, avgValue, minValue, maxValue];
}

class TelemetryModel extends Equatable {
  final String deviceId;
  final TelemetryMetric metric;
  final double value;
  final DateTime recordedAt;

  const TelemetryModel({
    required this.deviceId,
    required this.metric,
    required this.value,
    required this.recordedAt,
  });

  factory TelemetryModel.fromJson(Map<String, dynamic> json) => TelemetryModel(
        deviceId: json['device_id'] as String? ?? '',
        metric: TelemetryMetricExtension.fromString(
            json['metric'] as String? ?? 'power'),
        value: (json['value'] as num? ?? 0).toDouble(),
        recordedAt: json['recorded_at'] != null
            ? DateTime.parse(json['recorded_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'metric': metric.apiKey,
        'value': value,
        'recorded_at': recordedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [deviceId, metric, value, recordedAt];
}

class TelemetryHistoryModel extends Equatable {
  final String deviceId;
  final TelemetryMetric metric;
  final List<TelemetryPoint> dataPoints;

  const TelemetryHistoryModel({
    required this.deviceId,
    required this.metric,
    required this.dataPoints,
  });

  factory TelemetryHistoryModel.fromJson(Map<String, dynamic> json) =>
      TelemetryHistoryModel(
        deviceId: json['device_id'] as String? ?? '',
        metric: TelemetryMetricExtension.fromString(
            json['metric'] as String? ?? 'power'),
        dataPoints: (json['data_points'] as List<dynamic>? ?? [])
            .map((p) => TelemetryPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [deviceId, metric, dataPoints];
}
