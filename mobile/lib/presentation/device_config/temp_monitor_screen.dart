import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/device.model.dart';
import '../../controllers/mqtt.controller.dart';
import '../../data/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../common/widgets/glass_panel.dart';

class TempMonitorScreen extends ConsumerStatefulWidget {
  final DeviceModel device;
  const TempMonitorScreen({super.key, required this.device});

  @override
  ConsumerState<TempMonitorScreen> createState() => _TempMonitorScreenState();
}

class _TempMonitorScreenState extends ConsumerState<TempMonitorScreen> {
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
      final configStr = widget.device.config ?? '{}';
      final cfg = jsonDecode(configStr) as Map<String, dynamic>;
      setState(() {
        _minTemp = (cfg['min_temp'] as num?)?.toDouble() ?? 20.0;
        _maxTemp = (cfg['max_temp'] as num?)?.toDouble() ?? 40.0;
      });
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    
    try {
      final configStr = widget.device.config ?? '{}';
      final newConfig = Map<String, dynamic>.from(jsonDecode(configStr));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mqttState = ref.watch(mqttControllerProvider);
    final isDark = context.isDark;
    
    final currentTemp = ref.read(mqttControllerProvider.notifier).getTemperature(widget.device.id);
    final isFan1On = ref.read(mqttControllerProvider.notifier).isFan1On(widget.device.id);
    final isFan2On = ref.read(mqttControllerProvider.notifier).isFan2On(widget.device.id);
    final fan1Current = ref.read(mqttControllerProvider.notifier).getFan1Current(widget.device.id);
    final fan2Current = ref.read(mqttControllerProvider.notifier).getFan2Current(widget.device.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GlassPanel(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.thermostat_rounded, size: 48, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    '${currentTemp.toStringAsFixed(1)}°C',
                    style: AppTypography.h1.copyWith(fontSize: 64, color: isDark ? Colors.white : Colors.black87),
                  ),
                  Text('Live Temperature', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(isDark))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _FanStatusCard(title: 'Fan 1', isOn: isFan1On, current: fan1Current, isDark: isDark)),
                const SizedBox(width: 16),
                Expanded(child: _FanStatusCard(title: 'Fan 2', isOn: isFan2On, current: fan2Current, isDark: isDark)),
              ],
            ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Alert Thresholds', style: AppTypography.h3.copyWith(color: isDark ? Colors.white : Colors.black87)),
            ),
            const SizedBox(height: 16),
            GlassPanel(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Minimum Temp: ${_minTemp.toInt()}°C', style: AppTypography.bodyMedium.copyWith(color: isDark ? Colors.white70 : Colors.black87)),
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
                      Text('Maximum Temp: ${_maxTemp.toInt()}°C', style: AppTypography.bodyMedium.copyWith(color: isDark ? Colors.white70 : Colors.black87)),
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
        ),
      ),
    );
  }
}

class _FanStatusCard extends StatelessWidget {
  final String title;
  final bool isOn;
  final double current;
  final bool isDark;

  const _FanStatusCard({required this.title, required this.isOn, required this.current, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(
            isOn ? Icons.mode_fan_off_rounded : Icons.mode_fan_off_outlined,
            color: isOn ? Colors.blueAccent : AppColors.textSecondary(isDark),
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTypography.titleMedium.copyWith(color: isDark ? Colors.white : Colors.black87)),
          Text(isOn ? 'ON' : 'OFF', style: AppTypography.h3.copyWith(color: isOn ? Colors.blueAccent : AppColors.textSecondary(isDark))),
          const SizedBox(height: 4),
          Text('${current.toStringAsFixed(2)} A', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(isDark))),
        ],
      ),
    );
  }
}
