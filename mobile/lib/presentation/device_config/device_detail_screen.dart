import 'package:flutter/material.dart';
import 'switch_settings_screen.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/dashboard.controller.dart';
import '../../controllers/mqtt.controller.dart';
import '../../data/models/device.model.dart';
import '../../data/services/api_client.dart';
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
            if (device.deviceType == DeviceType.energyMeter) 
              _EnergyPanel(device: device, mqttState: mqttState),
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

class _EnergyPanel extends StatefulWidget {
  final DeviceModel device;
  final MqttState mqttState;
  const _EnergyPanel({required this.device, required this.mqttState});

  @override
  State<_EnergyPanel> createState() => _EnergyPanelState();
}

class _EnergyPanelState extends State<_EnergyPanel> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  List<dynamic> _historicalData = [];
  double _todayConsumed = 0.0;
  double _monthConsumed = 0.0;
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _loadHistory();
  }
  
  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final response = await ApiClient.instance.get('/devices/${widget.device.id}/energy/history');
      if (response.data['success'] == true) {
        setState(() {
          _historicalData = response.data['history'] as List;
          _todayConsumed = (response.data['today_consumed'] as num?)?.toDouble() ?? 0.0;
          _monthConsumed = (response.data['month_consumed'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      debugPrint('Failed to load history: $e');
    } finally {
      setState(() => _isLoadingHistory = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read 3-Phase Data (with fallbacks for legacy 1-phase payloads)
    final v1 = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'voltage_1') as num?)?.toDouble() ?? 
               (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'voltage') as num?)?.toDouble() ?? 0.0;
    final a1 = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'current_1') as num?)?.toDouble() ?? 
               (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'current') as num?)?.toDouble() ?? 0.0;
    final w1 = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'power_1') as num?)?.toDouble() ?? 
               (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'power') as num?)?.toDouble() ?? 0.0;
    final pf1 = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'pf_1') as num?)?.toDouble() ?? 
                (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'power_factor') as num?)?.toDouble() ?? 0.0;

    final v2 = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'voltage_2') as num?)?.toDouble() ?? 0.0;
    final a2 = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'current_2') as num?)?.toDouble() ?? 0.0;
    final w2 = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'power_2') as num?)?.toDouble() ?? 0.0;
    final pf2 = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'pf_2') as num?)?.toDouble() ?? 0.0;

    final v3 = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'voltage_3') as num?)?.toDouble() ?? 0.0;
    final a3 = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'current_3') as num?)?.toDouble() ?? 0.0;
    final w3 = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'power_3') as num?)?.toDouble() ?? 0.0;
    final pf3 = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'pf_3') as num?)?.toDouble() ?? 0.0;

    final totalPower = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'total_power') as num?)?.toDouble() ?? w1 + w2 + w3;
    final totalEnergy = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'total_energy') as num?)?.toDouble() ?? 
                        (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'energy') as num?)?.toDouble() ?? 0.0;
    
    // Determine if it's 3-phase (if phase 2 or 3 has voltage > 0)
    final is3Phase = v2 > 0 || v3 > 0;
    
    // Calculate 3-Phase Line-to-Line Voltage: (Avg V) * sqrt(3)
    double calculatedVoltage = v1; 
    if (is3Phase) {
      double avgV = (v1 + v2 + v3) / 3;
      calculatedVoltage = avgV * 1.73205; // Root 3 approximation
    }
    
    final isDark = context.isDark;

    // Calculate a dynamic color based on total power usage (green -> yellow -> red)
    Color powerColor = AppColors.success;
    if (totalPower > 5000) powerColor = AppColors.error;
    else if (totalPower > 2000) powerColor = Colors.orangeAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: is3Phase ? '3-Phase Energy Analytics' : 'Live Energy Analytics', padding: const EdgeInsets.only(bottom: 16)),
        GlassPanel(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          child: Column(
            children: [
              // Central Dynamic Power Gauge
              Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing Glow Effect
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 180 * _pulseAnimation.value,
                        height: 180 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: powerColor.withValues(alpha: 0.1 / _pulseAnimation.value),
                          boxShadow: [
                            BoxShadow(
                              color: powerColor.withValues(alpha: 0.2 / _pulseAnimation.value),
                              blurRadius: 30 * _pulseAnimation.value,
                              spreadRadius: 5 * _pulseAnimation.value,
                            )
                          ],
                        ),
                      );
                    },
                  ),
                  // Inner Ring
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark 
                          ? [Colors.grey.shade800, Colors.grey.shade900]
                          : [Colors.grey.shade100, Colors.grey.shade300],
                      ),
                      border: Border.all(
                        color: powerColor.withValues(alpha: 0.5),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
                          blurRadius: 10,
                          offset: const Offset(5, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt_rounded, color: powerColor, size: 36),
                        const SizedBox(height: 4),
                        Text(
                          totalPower.toStringAsFixed(1),
                          style: AppTypography.h2.copyWith(color: powerColor, fontSize: 28),
                        ),
                        Text(
                          'Total Watts',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(isDark)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              // Master Metrics
              Row(
                children: [
                  _MetricTile(
                    label: is3Phase ? '3-Phase Voltage (L-L)' : 'Voltage', 
                    value: '${calculatedVoltage.toStringAsFixed(1)} V', 
                    icon: Icons.electric_meter_rounded,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 12),
                  _MetricTile(
                    label: is3Phase ? 'Avg Current' : 'Current', 
                    value: '${(is3Phase ? ((a1 + a2 + a3) / 3) : a1).toStringAsFixed(2)} A', 
                    icon: Icons.waves_rounded,
                    color: Colors.deepPurpleAccent,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MetricTile(
                    label: 'Total Consumed', 
                    value: '${totalEnergy.toStringAsFixed(2)} kWh', 
                    icon: Icons.eco_rounded,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  _MetricTile(
                    label: is3Phase ? 'Avg Power Factor' : 'Power Factor', 
                    value: is3Phase ? ((pf1 + pf2 + pf3) / 3).toStringAsFixed(2) : pf1.toStringAsFixed(2), 
                    icon: Icons.speed_rounded,
                    color: Colors.orangeAccent,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Phase Breakdown
              if (is3Phase) ...[
                Align(
                  alignment: Alignment.centerLeft, 
                  child: Text('Phase Breakdown', style: AppTypography.titleMedium)
                ),
                const SizedBox(height: 12),
                _PhaseRow(phaseName: 'Phase 1 (R)', v: v1, a: a1, w: w1, pf: pf1, color: Colors.redAccent),
                const SizedBox(height: 8),
                _PhaseRow(phaseName: 'Phase 2 (Y)', v: v2, a: a2, w: w2, pf: pf2, color: Colors.amber),
                const SizedBox(height: 8),
                _PhaseRow(phaseName: 'Phase 3 (B)', v: v3, a: a3, w: w3, pf: pf3, color: Colors.blueAccent),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        AppSectionHeader(title: 'Consumption Summary', padding: const EdgeInsets.only(bottom: 16)),
        Row(
          children: [
            _MetricTile(
              label: 'Today (kWh)', 
              value: _todayConsumed.toStringAsFixed(2), 
              icon: Icons.today_rounded,
              color: Colors.green,
            ),
            const SizedBox(width: 12),
            _MetricTile(
              label: 'This Month (kWh)', 
              value: _monthConsumed.toStringAsFixed(2), 
              icon: Icons.calendar_month_rounded,
              color: Colors.teal,
            ),
          ],
        ),

        const SizedBox(height: 24),
        AppSectionHeader(title: 'Historical Usage (Past 3 Months)', padding: const EdgeInsets.only(bottom: 16)),
        GlassPanel(
          padding: const EdgeInsets.all(20),
          child: _isLoadingHistory 
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ))
              : _historicalData.isEmpty
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('No historical data available yet.'),
                    ))
                  : SizedBox(
                      height: 200,
                      // We will use a simple custom Bar graph since fl_chart might not be installed
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _historicalData.take(30).map((record) {
                          // Extract units_consumed
                          final units = (record['units_consumed'] as num?)?.toDouble() ?? 0.0;
                          final dateStr = record['date'] as String? ?? '';
                          final parsedDate = DateTime.tryParse(dateStr);
                          
                          // Determine max value for scaling (fallback to 10 if all zero)
                          final maxUnits = _historicalData.fold<double>(10.0, (m, r) {
                            final u = (r['units_consumed'] as num?)?.toDouble() ?? 0.0;
                            return u > m ? u : m;
                          });
                          
                          final heightPct = (units / maxUnits).clamp(0.0, 1.0);
                          
                          return Tooltip(
                            message: '${units.toStringAsFixed(2)} kWh\n${dateStr.split("T").first}',
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  units.toStringAsFixed(1),
                                  style: AppTypography.bodySmall.copyWith(fontSize: 8, color: AppColors.textSecondary(isDark)),
                                ),
                                const SizedBox(height: 4),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  width: 8,
                                  height: 140 * heightPct,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: AppTypography.h3.copyWith(color: color, fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(isDark), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final String phaseName;
  final double v, a, w, pf;
  final Color color;

  const _PhaseRow({
    required this.phaseName,
    required this.v,
    required this.a,
    required this.w,
    required this.pf,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(phaseName, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text('${w.toStringAsFixed(1)} W', style: AppTypography.bodyLarge),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${v.toStringAsFixed(1)} V', style: AppTypography.bodySmall),
                Text('${a.toStringAsFixed(2)} A', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(isDark))),
              ],
            ),
          ),
        ],
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
    final temp = (mqttState.getDeviceValue(deviceId, 'telemetry', 'temperature') as num?)?.toDouble() ?? 0.0;
    final fan1Current = (mqttState.getDeviceValue(deviceId, 'telemetry', 'fan1_current') as num?)?.toDouble() ?? 0.0;
    final fan2Current = (mqttState.getDeviceValue(deviceId, 'telemetry', 'fan2_current') as num?)?.toDouble() ?? 0.0;
    
    // We do NOT show raw current. Any current > 0.05A means the Fan is ON.
    bool fan1On = fan1Current > 0.05;
    bool fan2On = fan2Current > 0.05;

    return Column(
      children: [
        GlassPanel(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            children: [
              const Icon(Icons.thermostat_rounded, color: Colors.orangeAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                '${temp.toStringAsFixed(1)}°C',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
              ),
              const SizedBox(height: 8),
              Text('Live Temperature', style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary(context.isDark))),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppSectionHeader(title: 'Exhaust Fan Status', padding: const EdgeInsets.only(bottom: 16)),
        Row(
          children: [
            Expanded(child: _FanStatusCard(label: 'Fan 1', isOn: fan1On)),
            const SizedBox(width: 16),
            Expanded(child: _FanStatusCard(label: 'Fan 2', isOn: fan2On)),
          ],
        ),
      ],
    );
  }
}

class _FanStatusCard extends StatelessWidget {
  final String label;
  final bool isOn;
  const _FanStatusCard({required this.label, required this.isOn});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.mode_fan_off_rounded,
            color: isOn ? Colors.greenAccent : Colors.grey,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(label, style: AppTypography.titleMedium),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isOn ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isOn ? 'ON' : 'OFF',
              style: TextStyle(
                color: isOn ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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
                        onVerticalDragUpdate: (_) {}, // Prevents screen scrolling while touching dial
                        onHorizontalDragUpdate: (_) {}, // Prevents screen scrolling while touching dial
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

