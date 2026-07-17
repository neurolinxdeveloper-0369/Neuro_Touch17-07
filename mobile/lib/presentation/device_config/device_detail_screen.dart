import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/dashboard.controller.dart';
import '../../controllers/mqtt.controller.dart';
import '../../data/models/device.model.dart';
import '../../core/utils/extensions.dart';

const Color _primary = Color(0xFF4C6FFF);
const Color _darkBg = Color(0xFF010817);
const Color _cardDark = Color(0xFF45484D);
const Color _success = Color(0xFF00B894);
const Color _darkTextPrimary = Color(0xFFFFFFFF);
const Color _darkTextSecondary = Color(0xFFB2BEC3);
const Color _lightTextPrimary = Color(0xFF0F172A);
const Color _lightTextSecondary = Color(0xFF555E68);
const Color _borderDark = Color(0xFF55595E);
const Color _borderLight = Color(0xFFD1D5DB);

class DeviceDetailScreen extends ConsumerWidget {
  final String deviceId;

  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final allDevices = ref.watch(dashboardControllerProvider).devices;
    final device = allDevices.firstWhereOrNull((d) => d.id == deviceId);
    final mqttState = ref.watch(mqttControllerProvider);

    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Device')),
        body: const Center(child: Text('Device not found')),
      );
    }

    final isOnline = mqttState.isDeviceOnline(deviceId);
    final textPrimary = isDark ? _darkTextPrimary : _lightTextPrimary;

    return Scaffold(
      backgroundColor: isDark ? _darkBg : Colors.white,
      appBar: AppBar(
        title: Text(device.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? _darkBg : Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOnline ? _success : const Color(0xFF555E68),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: GoogleFonts.inter(
                    color: isOnline ? _success : const Color(0xFF555E68),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Device type header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? _cardDark : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? _borderDark : _borderLight,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: device.deviceType.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    device.deviceType.icon,
                    color: device.deviceType.color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.deviceType.displayName,
                        style: GoogleFonts.inter(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${device.id.substring(0, 12)}...',
                        style: GoogleFonts.inter(
                          color: isDark ? _darkTextSecondary : _lightTextSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Switches section (for touch panels)
          if (device.deviceType == DeviceType.touchPanel && device.switches.isNotEmpty)
            _SwitchPanel(
              device: device,
              isDark: isDark,
              onToggle: (switchIndex, state) {
                ref.read(mqttControllerProvider.notifier).publishSwitchCommand(
                      deviceId,
                      switchIndex,
                      state,
                    );
              },
            ),

          // Energy meter readings
          if (device.deviceType == DeviceType.energyMeter)
            _EnergyPanel(device: device, mqttState: mqttState, isDark: isDark),

          // Temp monitor
          if (device.deviceType == DeviceType.tempMonitor)
            _TempPanel(deviceId: deviceId, mqttState: mqttState, isDark: isDark),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _SwitchPanel extends ConsumerWidget {
  final DeviceModel device;
  final bool isDark;
  final Function(int, bool) onToggle;

  const _SwitchPanel({
    required this.device,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mqttState = ref.watch(mqttControllerProvider);
    final textPrimary = isDark ? _darkTextPrimary : _lightTextPrimary;
    final textSecondary = isDark ? _darkTextSecondary : _lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Switches',
          style: GoogleFonts.inter(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...device.switches.map((sw) {
          final currentState = mqttState.getDeviceValue(
                device.id, 'switch', 'sw${sw.switchIndex}') as bool? ??
            false;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? _cardDark : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? _borderDark : _borderLight,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.power_settings_new_rounded,
                    color: currentState ? _primary : textSecondary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sw.name,
                    style: GoogleFonts.inter(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Switch(
                  value: currentState,
                  onChanged: (v) => onToggle(sw.switchIndex, v),
                  activeThumbColor: _primary,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _EnergyPanel extends StatelessWidget {
  final DeviceModel device;
  final MqttState mqttState;
  final bool isDark;

  const _EnergyPanel({
    required this.device,
    required this.mqttState,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? _darkTextPrimary : _lightTextPrimary;
    final watts = mqttState.getWatts(device.id);
    final voltage = (mqttState.getDeviceValue(
              device.id, 'energy', 'voltage') as num?)
            ?.toDouble() ??
        0.0;
    final current = (mqttState.getDeviceValue(
              device.id, 'energy', 'current') as num?)
            ?.toDouble() ??
        0.0;
    final energy = (mqttState.getDeviceValue(
              device.id, 'energy', 'energy') as num?)
            ?.toDouble() ??
        0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Readings',
          style: GoogleFonts.inter(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _MetricTile(label: 'Power', value: watts.toWattsString, isDark: isDark, color: const Color(0xFF4C6FFF)),
            const SizedBox(width: 10),
            _MetricTile(label: 'Voltage', value: voltage.toVoltageString, isDark: isDark, color: const Color(0xFF00B894)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _MetricTile(label: 'Current', value: current.toCurrentString, isDark: isDark, color: const Color(0xFFFDCB6E)),
            const SizedBox(width: 10),
            _MetricTile(label: 'Energy', value: energy.toKwhString, isDark: isDark, color: const Color(0xFF6C5CE7)),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? _cardDark : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? _borderDark : _borderLight,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isDark ? _darkTextSecondary : _lightTextSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TempPanel extends StatelessWidget {
  final String deviceId;
  final MqttState mqttState;
  final bool isDark;

  const _TempPanel({
    required this.deviceId,
    required this.mqttState,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final temp = mqttState.getTemperature(deviceId);
    final humidity = (mqttState.getDeviceValue(
              deviceId, 'temperature', 'humidity') as num?)
            ?.toDouble() ??
        0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? _cardDark : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? _borderDark : _borderLight,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  temp.toTempString,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF4C6FFF),
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Temperature',
                  style: GoogleFonts.inter(
                    color: isDark ? _darkTextSecondary : _lightTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  humidity.toHumidityString,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF00CEC9),
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Humidity',
                  style: GoogleFonts.inter(
                    color: isDark ? _darkTextSecondary : _lightTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
