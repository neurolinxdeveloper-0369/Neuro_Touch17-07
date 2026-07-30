import '../../data/services/api_service.dart';
import 'dart:convert';
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

class DeviceDetailScreen extends ConsumerStatefulWidget {
  final String deviceId;

  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  ConsumerState<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends ConsumerState<DeviceDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(mqttControllerProvider.notifier).requestDeviceStatus(widget.deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final allDevices = ref.watch(dashboardControllerProvider).devices;
    final device = allDevices.firstWhereOrNull((d) => d.id == widget.deviceId);
    final mqttState = ref.watch(mqttControllerProvider);

    if (device == null) {
      return const AppScreenWrapper(
        title: 'Device Not Found',
        child: Center(child: Text('Device not found')),
      );
    }

    final isOnline = mqttState.isDeviceOnline(widget.deviceId);

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
                onToggle: (idx, state) => ref.read(mqttControllerProvider.notifier).publishSwitchCommand(widget.deviceId, idx, state),
              ),
            if (device.deviceType == DeviceType.energyMeter) 
              _EnergyPanel(device: device, mqttState: mqttState, isOnline: isOnline),
            if (device.deviceType == DeviceType.tempMonitor) _TempPanel(device: device, mqttState: mqttState),
            if (device.deviceType == DeviceType.gasControl) _GasControlPanel(deviceId: widget.deviceId, mqttState: mqttState),
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
    final isOnline = ref.watch(deviceOnlineProvider(device.id));

    // Always iterate 1..switchCount so every switch gets an MQTT binding.
    // If a switch has a saved config, use its name/icon.
    // If not (newly provisioned or not yet configured), fall back to defaults.
    // This ensures ALL switches toggle correctly, even when only some have configs.
    final Map<int, bool> switchStates = {};
    final Map<int, String> switchNames = {};
    final Map<int, String> switchIcons = {};

    for (int i = 1; i <= device.switchCount; i++) {
      final config = device.switches.firstWhereOrNull((s) => s.switchIndex == i);
      final configVal = device.config['$i'];
      bool savedState = false;
      if (configVal is bool) savedState = configVal;
      
      switchStates[i] =
          mqttState.getDeviceValue(device.id, 'switch', 'sw$i') as bool? ?? savedState;
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
          isOnline: isOnline,
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
  final bool isOnline;
  const _EnergyPanel({required this.device, required this.mqttState, required this.isOnline});

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

  @override
  void didUpdateWidget(_EnergyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pause pulse animation when offline, resume when online
    if (!widget.isOnline && _pulseController.isAnimating) {
      _pulseController.stop();
    } else if (widget.isOnline && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
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
    // ── Read R/Y/B Phase Data from MQTT ────────────────────────────────────
    double _m(String key) => (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', key) as num?)?.toDouble() ?? 0.0;

    // Phase R (also used for 1-phase fallback)
    final vR  = _m('voltage_r') > 0 ? _m('voltage_r') : _m('voltage');
    final iR  = _m('current_r') > 0 ? _m('current_r') : _m('current');
    final kwR = _m('power_r')   > 0 ? _m('power_r')   : _m('power');    // kW
    final eR  = _m('energy_r')  > 0 ? _m('energy_r')  : _m('energy_kwh'); // kWh

    // Phase Y
    final vY  = _m('voltage_y');
    final iY  = _m('current_y');
    final kwY = _m('power_y');
    final eY  = _m('energy_y');

    // Phase B
    final vB  = _m('voltage_b');
    final iB  = _m('current_b');
    final kwB = _m('power_b');
    final eB  = _m('energy_b');

    // Line-to-line voltages (sent by firmware)
    final vRY = _m('v_ry');
    final vYB = _m('v_yb');
    final vBR = _m('v_br');

    // Single PF (avg across phases)
    final pf  = _m('pf') > 0 ? _m('pf') : _m('power_factor');

    // Totals
    final totalKW  = _m('total_power')  > 0 ? _m('total_power')  : (kwR + kwY + kwB);
    final totalKWh = _m('total_energy') > 0 ? _m('total_energy') : (eR  + eY  + eB);

    // 3-phase detected when phase Y or B has voltage
    final is3Phase = vY > 0 || vB > 0;

    final isDark = context.isDark;
    final isOnline = widget.isOnline;

    // ── Offline zeros ──────────────────────────────────────────────────────
    final double effVR      = isOnline ? vR  : 0.0;
    final double effVY      = isOnline ? vY  : 0.0;
    final double effVB      = isOnline ? vB  : 0.0;
    final double effVRY     = isOnline ? vRY : 0.0;
    final double effVYB     = isOnline ? vYB : 0.0;
    final double effVBR     = isOnline ? vBR : 0.0;
    final double effIR      = isOnline ? iR  : 0.0;
    final double effIY      = isOnline ? iY  : 0.0;
    final double effIB      = isOnline ? iB  : 0.0;
    final double effKWR     = isOnline ? kwR : 0.0;
    final double effKWY     = isOnline ? kwY : 0.0;
    final double effKWB     = isOnline ? kwB : 0.0;
    final double effER      = isOnline ? eR  : 0.0;
    final double effEY      = isOnline ? eY  : 0.0;
    final double effEB      = isOnline ? eB  : 0.0;
    final double effPf      = isOnline ? pf  : 0.0;
    final double effTotalKW = isOnline ? totalKW  : 0.0;
    final double effTotalE  = isOnline ? totalKWh : 0.0;
    final bool   eff3Ph     = isOnline && is3Phase;

    // Gauge colour: grey offline, green→orange→red by kW
    Color powerColor = isOnline ? AppColors.success : Colors.grey.shade600;
    if (isOnline) {
      if (totalKW > 5.0)  powerColor = AppColors.error;
      else if (totalKW > 2.0) powerColor = Colors.orangeAccent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: effective3Ph ? '3-Phase Energy Analytics' : 'Live Energy Analytics', padding: const EdgeInsets.only(bottom: 16)),
        // ── Offline banner ──────────────────────────────────────────────────
        if (!isOnline)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade800.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade600),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.grey.shade400, size: 18),
                const SizedBox(width: 10),
                Text('Device Offline — Values will resume when reconnected',
                    style: AppTypography.bodySmall.copyWith(color: Colors.grey.shade400)),
              ],
            ),
          ),
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
                          effTotalKW.toStringAsFixed(3),
                          style: AppTypography.h2.copyWith(color: powerColor, fontSize: 28),
                        ),
                        Text(
                          isOnline ? 'Total kW' : 'Offline',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(isDark)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              // ── Master Metrics ────────────────────────────────────────────
              Row(
                children: [
                  _MetricTile(
                    label: eff3Ph ? 'V-RY (Line)' : 'Voltage',
                    value: eff3Ph ? '${effVRY.toStringAsFixed(1)} V' : '${effVR.toStringAsFixed(1)} V',
                    icon: Icons.electric_meter_rounded,
                    color: isOnline ? Colors.blueAccent : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  _MetricTile(
                    label: eff3Ph ? 'R Phase Current' : 'Current',
                    value: '${effIR.toStringAsFixed(4)} A',
                    icon: Icons.waves_rounded,
                    color: isOnline ? Colors.deepPurpleAccent : Colors.grey.shade600,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MetricTile(
                    label: 'Total Energy',
                    value: '${effTotalE.toStringAsFixed(4)} kWh',
                    icon: Icons.eco_rounded,
                    color: isOnline ? AppColors.success : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  _MetricTile(
                    label: 'Power Factor',
                    value: effPf.toStringAsFixed(2),
                    icon: Icons.speed_rounded,
                    color: isOnline ? Colors.orangeAccent : Colors.grey.shade600,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 3-Phase Detail Section ────────────────────────────────────
              if (eff3Ph) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Phase Breakdown', style: AppTypography.titleMedium),
                ),
                const SizedBox(height: 12),
                // Line voltages row
                Row(
                  children: [
                    _SmallMetric(label: 'V-RY', value: '${effVRY.toStringAsFixed(1)} V', color: Colors.red.shade300),
                    const SizedBox(width: 8),
                    _SmallMetric(label: 'V-YB', value: '${effVYB.toStringAsFixed(1)} V', color: Colors.amber),
                    const SizedBox(width: 8),
                    _SmallMetric(label: 'V-BR', value: '${effVBR.toStringAsFixed(1)} V', color: Colors.blue.shade300),
                  ],
                ),
                const SizedBox(height: 10),
                _PhaseRow3(
                  phaseName: 'R Phase',
                  vPN: effVR, current: effIR, powerKW: effKWR, energyKWh: effER,
                  color: isOnline ? Colors.redAccent : Colors.grey.shade600,
                ),
                const SizedBox(height: 8),
                _PhaseRow3(
                  phaseName: 'Y Phase',
                  vPN: effVY, current: effIY, powerKW: effKWY, energyKWh: effEY,
                  color: isOnline ? Colors.amber : Colors.grey.shade600,
                ),
                const SizedBox(height: 8),
                _PhaseRow3(
                  phaseName: 'B Phase',
                  vPN: effVB, current: effIB, powerKW: effKWB, energyKWh: effEB,
                  color: isOnline ? Colors.blueAccent : Colors.grey.shade600,
                ),
              ],

              // ── 1-Phase extra row (frequency) ─────────────────────────────
              if (!eff3Ph) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MetricTile(
                      label: 'Power (kW)',
                      value: '${effKWR.toStringAsFixed(4)} kW',
                      icon: Icons.flash_on_rounded,
                      color: isOnline ? Colors.deepOrangeAccent : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 12),
                    _MetricTile(
                      label: 'Frequency',
                      value: '${(isOnline ? (widget.mqttState.getDeviceValue(widget.device.id, "telemetry", "frequency") as num?)?.toDouble() ?? 0.0 : 0.0).toStringAsFixed(1)} Hz',
                      icon: Icons.graphic_eq_rounded,
                      color: isOnline ? Colors.tealAccent : Colors.grey.shade600,
                    ),
                  ],
                ),
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
              value: _todayConsumed.toStringAsFixed(4), 
              icon: Icons.today_rounded,
              color: Colors.green,
            ),
            const SizedBox(width: 12),
            _MetricTile(
              label: 'This Month (kWh)', 
              value: _monthConsumed.toStringAsFixed(4), 
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

/// Compact chip for line-to-line voltages (V-RY, V-YB, V-BR)
class _SmallMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SmallMetric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: AppTypography.bodySmall.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(value, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Full phase row: phaseName | V(L-N) | Current | Power kW | Energy kWh
class _PhaseRow3 extends StatelessWidget {
  final String phaseName;
  final double vPN, current, powerKW, energyKWh;
  final Color color;

  const _PhaseRow3({
    required this.phaseName,
    required this.vPN,
    required this.current,
    required this.powerKW,
    required this.energyKWh,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Phase colour bar
          Container(width: 4, height: 48, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          // Phase name
          SizedBox(
            width: 60,
            child: Text(phaseName, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, color: color)),
          ),
          // V (L-N)
          Expanded(child: _Col(label: 'V(L-N)', value: '${vPN.toStringAsFixed(1)}V', isDark: isDark)),
          // Current
          Expanded(child: _Col(label: 'Current', value: '${current.toStringAsFixed(4)}A', isDark: isDark)),
          // Power kW
          Expanded(child: _Col(label: 'Power', value: '${powerKW.toStringAsFixed(4)}kW', isDark: isDark)),
          // Energy kWh
          Expanded(child: _Col(label: 'Energy', value: '${energyKWh.toStringAsFixed(4)}kWh', isDark: isDark)),
        ],
      ),
    );
  }
}

class _Col extends StatelessWidget {
  final String label, value;
  final bool isDark;
  const _Col({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: AppTypography.bodySmall.copyWith(fontSize: 9, color: AppColors.textSecondary(isDark))),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
      ],
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
                Text('${a.toStringAsFixed(4)} A', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(isDark))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TempPanel extends ConsumerStatefulWidget {
  final DeviceModel device;
  final MqttState mqttState;
  const _TempPanel({required this.device, required this.mqttState});

  @override
  ConsumerState<_TempPanel> createState() => _TempPanelState();
}

class _TempPanelState extends ConsumerState<_TempPanel> {
  double _minTemp = 20.0;
  double _maxTemp = 40.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    try {
      final cfg = widget.device.config;
      setState(() {
        _minTemp = (cfg['min_temp'] as num?)?.toDouble() ?? 20.0;
        _maxTemp = (cfg['max_temp'] as num?)?.toDouble() ?? 40.0;
      });
    } catch (e) {
      // Ignore parse errors
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final newConfig = Map<String, dynamic>.from(widget.device.config);
      newConfig['min_temp'] = _minTemp;
      newConfig['max_temp'] = _maxTemp;

      final api = ref.read(apiServiceProvider);
      await api.put('/api/v1/devices/${widget.device.id}', {
        'config': jsonEncode(newConfig),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thresholds saved!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save thresholds: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final temp = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'temperature') as num?)?.toDouble() ?? 0.0;
    final fan1Current = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'fan1_current') as num?)?.toDouble() ?? 0.0;
    final fan2Current = (widget.mqttState.getDeviceValue(widget.device.id, 'telemetry', 'fan2_current') as num?)?.toDouble() ?? 0.0;
    
    // We do NOT show raw current. Any current > 0.05A means the Fan is ON.
    bool fan1On = fan1Current > 0.05;
    bool fan2On = fan2Current > 0.05;
    final isDark = context.isDark;

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
        const SizedBox(height: 32),
        AppSectionHeader(title: 'Alert Thresholds', padding: const EdgeInsets.only(bottom: 16)),
        GlassPanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Min: ${_minTemp.toInt()}°C', style: AppTypography.bodyMedium.copyWith(color: isDark ? Colors.white70 : Colors.black87)),
                  Expanded(
                    child: Slider(
                      value: _minTemp,
                      min: 0,
                      max: 50,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) => setState(() => _minTemp = val),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Max: ${_maxTemp.toInt()}°C', style: AppTypography.bodyMedium.copyWith(color: isDark ? Colors.white70 : Colors.black87)),
                  Expanded(
                    child: Slider(
                      value: _maxTemp,
                      min: 30,
                      max: 200,
                      activeColor: Colors.deepOrangeAccent,
                      onChanged: (val) => setState(() => _maxTemp = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveConfig,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('Save Thresholds', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
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

