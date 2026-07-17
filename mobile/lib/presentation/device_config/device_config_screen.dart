import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/dashboard.controller.dart';
import '../../controllers/mqtt.controller.dart';
import '../../data/models/device.model.dart';
import '../../core/utils/extensions.dart';

const Color _primary = Color(0xFF4C6FFF);
const Color _darkBg = Color(0xFF010817);
const Color _cardDark = Color(0xFF45484D);
const Color _darkTextPrimary = Color(0xFFFFFFFF);
const Color _darkTextSecondary = Color(0xFFB2BEC3);
const Color _lightTextPrimary = Color(0xFF0F172A);
const Color _lightTextSecondary = Color(0xFF555E68);
const Color _borderDark = Color(0xFF55595E);
const Color _borderLight = Color(0xFFD1D5DB);

class DeviceConfigScreen extends ConsumerStatefulWidget {
  const DeviceConfigScreen({super.key});

  @override
  ConsumerState<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends ConsumerState<DeviceConfigScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final devices = ref.watch(dashboardControllerProvider).devices;
    final mqttState = ref.watch(mqttControllerProvider);

    final filtered = _filter == 'all'
        ? devices
        : devices.where((d) => d.deviceType.apiValue == _filter).toList();

    final textSecondary = isDark ? _darkTextSecondary : _lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? _darkBg : Colors.white,
      appBar: AppBar(
        title: Text(
          'Devices',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: isDark ? _darkBg : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/add-device'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Type filter
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final filters = [
                  ('all', 'All'),
                  ('touch_panel', 'Touch Panel'),
                  ('ir_blaster', 'IR Blaster'),
                  ('lift_panel', 'Lift'),
                  ('energy_meter', 'Energy'),
                  ('temp_monitor', 'Temp'),
                ];
                final f = filters[index];
                final isSelected = _filter == f.$1;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? _primary
                            : (isDark ? _borderDark : _borderLight),
                      ),
                    ),
                    child: Text(
                      f.$2,
                      style: GoogleFonts.inter(
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? _darkTextSecondary
                                : _lightTextSecondary),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Device list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.devices_other_outlined,
                            size: 48,
                            color: isDark
                                ? _darkTextSecondary
                                : _lightTextSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No devices found',
                          style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final device = filtered[index];
                      final isOnline = mqttState.isDeviceOnline(device.id);
                      return _DeviceConfigCard(
                        device: device,
                        isOnline: isOnline,
                        isDark: isDark,
                        onTap: () => context.push('/devices/${device.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeviceConfigCard extends StatelessWidget {
  final DeviceModel device;
  final bool isOnline;
  final bool isDark;
  final VoidCallback onTap;

  const _DeviceConfigCard({
    required this.device,
    required this.isOnline,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? _cardDark : Colors.white;
    final textPrimary = isDark ? _darkTextPrimary : _lightTextPrimary;
    final textSecondary = isDark ? _darkTextSecondary : _lightTextSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? _borderDark : _borderLight,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: device.deviceType.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                device.deviceType.icon,
                color: device.deviceType.color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: GoogleFonts.inter(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? const Color(0xFF00B894)
                              : const Color(0xFF555E68),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: GoogleFonts.inter(
                          color: isOnline
                              ? const Color(0xFF00B894)
                              : textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(color: textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        device.deviceType.shortName,
                        style: GoogleFonts.inter(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
