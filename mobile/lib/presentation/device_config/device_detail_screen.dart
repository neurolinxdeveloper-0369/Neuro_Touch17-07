import 'package:flutter/material.dart';
import 'switch_settings_screen.dart';
import 'package:collection/collection.dart';
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
            if (device.switchCount > 0)
              _SwitchPanel(
                device: device,
                onToggle: (idx, state) => ref.read(mqttControllerProvider.notifier).publishSwitchCommand(deviceId, idx, state),
              ),
            if (device.deviceType == DeviceType.energyMeter) _EnergyPanel(device: device, mqttState: mqttState),
            if (device.deviceType == DeviceType.tempMonitor) _TempPanel(deviceId: deviceId, mqttState: mqttState),
            if (device.deviceType == DeviceType.gasControl) _GasControlPanel(deviceId: deviceId, mqttState: mqttState),
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

    // Always iterate 1..switchCount so every switch gets an MQTT binding.
    // If a switch has a saved config, use its name/icon.
    // If not (newly provisioned or not yet configured), fall back to defaults.
    // This ensures ALL switches toggle correctly, even when only some have configs.
    final Map<int, bool> switchStates = {};
    final Map<int, String> switchNames = {};
    final Map<int, String> switchIcons = {};

    for (int i = 1; i <= device.switchCount; i++) {
      final config = device.switches.firstWhereOrNull((s) => s.switchIndex == i);
      switchStates[i] =
          mqttState.getDeviceValue(device.id, 'switch', 'sw$i') as bool? ?? false;
      switchNames[i] = config?.name ?? 'Switch $i';
      switchIcons[i] = config?.icon ?? 'lightbulb';
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
          isCustomLayout: device.deviceType == DeviceType.customTouchPanel,
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

class _GasControlPanel extends StatefulWidget {
  final String deviceId;
  final MqttState mqttState;

  const _GasControlPanel({required this.deviceId, required this.mqttState});

  @override
  State<_GasControlPanel> createState() => _GasControlPanelState();
}

class _GasControlPanelState extends State<_GasControlPanel> {
  // Ordered as physically present on the stove: OFF -> HIGH -> MED -> LOW
  final List<String> states = ['OFF', 'HIGH', 'MED', 'LOW'];

  double _getRotationForState(String state) {
    switch (state.toUpperCase()) {
      case 'OFF': return -0.35; // turns (-126 degrees)
      case 'HIGH': return -0.12; // turns (-43 degrees)
      case 'MED': return 0.12; // turns (43 degrees)
      case 'LOW': return 0.35; // turns (126 degrees)
      default: return -0.35;
    }
  }

  Color _getColorForState(String state) {
    switch (state.toUpperCase()) {
      case 'OFF': return Colors.grey.shade400;
      case 'HIGH': return Colors.redAccent;
      case 'MED': return Colors.orangeAccent;
      case 'LOW': return Colors.amber;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    // Read state from MQTT telemetry if available
    final gasFeature = widget.mqttState.getFeatureMap(widget.deviceId, 'gas');
    String currentState = 'OFF';
    if (gasFeature.isNotEmpty && gasFeature['motors'] != null) {
      try {
        final motors = gasFeature['motors'] as List;
        if (motors.isNotEmpty) {
          currentState = (motors[0]['state'] as String).toUpperCase();
        }
      } catch (e) {
        // Fallback to OFF if parsing fails
      }
    }
    
    final activeColor = _getColorForState(currentState);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: 'Gas Burner Control', padding: const EdgeInsets.only(bottom: 12)),
        GlassPanel(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          child: Column(
            children: [
              // Dynamic Knob Design
              Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Dial Marks
                      ...states.asMap().entries.map((entry) {
                        final index = entry.key;
                        final state = entry.value;
                        final rotation = _getRotationForState(state);
                        final isSelected = currentState == state;
                        final color = isSelected ? _getColorForState(state) : AppColors.textSecondary(isDark).withValues(alpha: 0.3);
                        
                        return AnimatedRotation(
                          turns: rotation,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutBack,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 4,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 2)] : [],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    state,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: color,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      
                      // The Knob itself
                      GestureDetector(
                        onTapDown: (_) {
                          // Allow cycling through states by tapping the center knob
                          final currentIndex = states.indexOf(currentState);
                          final nextIndex = (currentIndex + 1) % states.length;
                          final newState = states[nextIndex];
                          
                          // Publish MQTT command via Provider
                          final container = ProviderScope.containerOf(context, listen: false);
                          container.read(mqttControllerProvider.notifier).publishGasCommand(
                            widget.deviceId,
                            'setPreset',
                            newState.toLowerCase(),
                            1, // Assuming Motor ID 1
                          );
                        },
                        child: AnimatedRotation(
                          turns: _getRotationForState(currentState),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutBack,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark 
                                  ? [Colors.grey.shade800, Colors.grey.shade900]
                                  : [Colors.grey.shade100, Colors.grey.shade300],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
                                  blurRadius: 15,
                                  offset: const Offset(5, 5),
                                ),
                                BoxShadow(
                                  color: isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.white,
                                  blurRadius: 15,
                                  offset: const Offset(-5, -5),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Center glow
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: activeColor.withValues(alpha: 0.1),
                                  ),
                                ),
                                // Indicator line on the knob
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 15),
                                    width: 6,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: activeColor,
                                      borderRadius: BorderRadius.circular(3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: activeColor.withValues(alpha: 0.8),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Preset control buttons below the knob
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: states.map((state) {
                  final isSelected = currentState == state;
                  final color = _getColorForState(state);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: GestureDetector(
                        onTap: () {
                          // Publish MQTT command
                          final container = ProviderScope.containerOf(context, listen: false);
                          container.read(mqttControllerProvider.notifier).publishGasCommand(
                            widget.deviceId,
                            'setPreset',
                            state.toLowerCase(),
                            1, // Assuming Motor ID 1
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? color : AppColors.borderColor(isDark),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            state,
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? color : AppColors.textSecondary(isDark),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),
              // Safety Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 24, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Safety Gate: Remote ignition is disabled if the knob is completely OFF. Please turn the physical knob to ignite.',
                        style: AppTypography.bodySmall.copyWith(color: isDark ? Colors.orange.shade200 : Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

