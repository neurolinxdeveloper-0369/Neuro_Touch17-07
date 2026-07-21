import 'package:flutter/material.dart';
import 'switch_settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/dashboard.controller.dart';
import '../../controllers/mqtt.controller.dart';
import '../../data/models/device.model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../common/widgets/app_screen_wrapper.dart';
import '../common/widgets/glass_panel.dart';
import '../common/widgets/app_section_header.dart';
import '../add_device/provisioning/widgets/circular_switch.dart';

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
      return const AppScreenWrapper(
        title: 'Device Not Found',
        child: Center(child: Text('Device not found')),
      );
    }

    final isOnline = mqttState.isDeviceOnline(deviceId);

    return AppScreenWrapper(
      title: device.name,
      actions: [
        _OnlineStatusIndicator(isOnline: isOnline),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            _DeviceHeader(device: device),
            const SizedBox(height: 24),
            if (device.deviceType == DeviceType.touchPanel)
              _SwitchPanel(
                device: device,
                onToggle: (idx, state) => ref.read(mqttControllerProvider.notifier).publishSwitchCommand(deviceId, idx, state),
              ),
            if (device.deviceType == DeviceType.energyMeter) _EnergyPanel(device: device, mqttState: mqttState),
            if (device.deviceType == DeviceType.tempMonitor) _TempPanel(deviceId: deviceId, mqttState: mqttState),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _OnlineStatusIndicator extends StatelessWidget {
  final bool isOnline;
  const _OnlineStatusIndicator({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: isOnline ? AppColors.success : AppColors.error, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(isOnline ? 'Online' : 'Offline', style: AppTypography.bodySmall.copyWith(color: isOnline ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DeviceHeader extends StatelessWidget {
  final DeviceModel device;
  const _DeviceHeader({required this.device});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: device.deviceType.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(device.deviceType.icon, color: device.deviceType.color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.deviceType.displayName, style: AppTypography.titleLarge),
                Text('ID: ${device.id.truncate(16)}', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(isDark))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchPanel extends ConsumerWidget {
  final DeviceModel device;
  final Function(int, bool) onToggle;
  const _SwitchPanel({required this.device, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mqttState = ref.watch(mqttControllerProvider);

    // Build switch state map from MQTT values
    final Map<int, bool> switchStates = {};
    final Map<int, String> switchNames = {};
    final Map<int, String> switchIcons = {};
    for (final sw in device.switches) {
      switchStates[sw.switchIndex] =
          mqttState.getDeviceValue(device.id, 'switch', 'sw${sw.switchIndex}') as bool? ?? false;
      switchNames[sw.switchIndex] = sw.name;
      switchIcons[sw.switchIndex] = sw.icon;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Switches (${device.switchCount})',
          padding: const EdgeInsets.only(bottom: 16),
        ),
        CircularSwitchGrid(
          switchCount: device.switchCount,
          switchStates: switchStates,
          switchNames: switchNames,
          switchIcons: switchIcons,
          onToggle: (idx, state) => onToggle(idx, state),
          onLongPress: (idx) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SwitchSettingsScreen(
                  device: device,
                  switchIndex: idx,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _EnergyPanel extends StatelessWidget {
  final DeviceModel device;
  final MqttState mqttState;
  const _EnergyPanel({required this.device, required this.mqttState});

  @override
  Widget build(BuildContext context) {
    final watts = mqttState.getWatts(device.id);
    final voltage = (mqttState.getDeviceValue(device.id, 'energy', 'voltage') as num?)?.toDouble() ?? 0.0;
    final current = (mqttState.getDeviceValue(device.id, 'energy', 'current') as num?)?.toDouble() ?? 0.0;
    final totalKwh = (mqttState.getDeviceValue(device.id, 'energy', 'energy') as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: 'Energy Usage', padding: const EdgeInsets.only(bottom: 12)),
        Row(
          children: [
            _MetricTile(label: 'Power', value: watts.toWattsString, color: AppColors.primaryLight),
            const SizedBox(width: 12),
            _MetricTile(label: 'Voltage', value: voltage.toVoltageString, color: AppColors.success),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _MetricTile(label: 'Current', value: current.toCurrentString, color: AppColors.warning),
            const SizedBox(width: 12),
            _MetricTile(label: 'Total Energy', value: totalKwh.toKwhString, color: Colors.purpleAccent),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTypography.h3.copyWith(color: color)),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context.isDark))),
          ],
        ),
      ),
    );
  }
}

class _TempPanel extends StatelessWidget {
  final String deviceId;
  final MqttState mqttState;
  const _TempPanel({required this.deviceId, required this.mqttState});

  @override
  Widget build(BuildContext context) {
    final temp = mqttState.getTemperature(deviceId);
    final humidity = (mqttState.getDeviceValue(deviceId, 'temperature', 'humidity') as num?)?.toDouble() ?? 0.0;

    return GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _CircleMetric(value: temp.toTempString, label: 'Temperature', icon: Icons.thermostat_rounded, color: Colors.orangeAccent),
          Container(width: 1, height: 60, color: AppColors.borderColor(context.isDark)),
          _CircleMetric(value: humidity.toHumidityString, label: 'Humidity', icon: Icons.water_drop_rounded, color: Colors.blueAccent),
        ],
      ),
    );
  }
}

class _CircleMetric extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _CircleMetric({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value, style: AppTypography.h2),
        Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context.isDark))),
      ],
    );
  }
}
