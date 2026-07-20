import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/dashboard.controller.dart';
import '../../controllers/mqtt.controller.dart';
import '../../data/models/device.model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../common/widgets/app_screen_wrapper.dart';
import '../common/widgets/glass_panel.dart';

class DeviceConfigScreen extends ConsumerStatefulWidget {
  const DeviceConfigScreen({super.key});

  @override
  ConsumerState<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends ConsumerState<DeviceConfigScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeId = ref.read(homeIdProvider);
      if (homeId != null && homeId.isNotEmpty) {
        ref.read(dashboardControllerProvider.notifier).refreshDevices(homeId);
      }
    });
  }

  Future<void> _handleRefresh() async {
    final homeId = ref.read(homeIdProvider);
    if (homeId != null && homeId.isNotEmpty) {
      await ref.read(dashboardControllerProvider.notifier).refreshDevices(homeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(dashboardControllerProvider).devices;
    final mqttState = ref.watch(mqttControllerProvider);
    final isDark = context.isDark;

    final filtered = _filter == 'all'
        ? devices
        : devices.where((d) => d.deviceType.apiValue == _filter).toList();

    return AppScreenWrapper(
      title: 'Devices',
      scrollable: false,
      actions: [
        IconButton(
          onPressed: () => context.push('/add-device'),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      child: Column(
        children: [
          const SizedBox(height: 12),
          _DeviceTypeFilter(
            currentFilter: _filter,
            onFilterChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: filtered.isEmpty
                  ? Stack(
                      children: [
                        ListView(),
                        _EmptyDevices(isDark: isDark),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final device = filtered[index];
                        final isOnline = mqttState.isDeviceOnline(device.id);
                        return _DeviceCard(
                          device: device,
                          isOnline: isOnline,
                          onTap: () => context.push('/devices/${device.id}'),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTypeFilter extends StatelessWidget {
  final String currentFilter;
  final ValueChanged<String> onFilterChanged;

  const _DeviceTypeFilter({required this.currentFilter, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('all', 'All'),
      ('touch_panel', 'Touch'),
      ('ir_blaster', 'Remote'),
      ('lift_panel', 'Lift'),
      ('energy_meter', 'Energy'),
      ('temp_monitor', 'Climate'),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = currentFilter == f.$1;

          return _FilterChip(
            label: f.$2,
            isSelected: isSelected,
            onTap: () => onFilterChanged(f.$1),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBackground(context.isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderColor(context.isDark), width: 0.5),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: isSelected ? Colors.white : AppColors.textPrimary(context.isDark),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final bool isOnline;
  final VoidCallback onTap;

  const _DeviceCard({required this.device, required this.isOnline, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: device.deviceType.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(device.deviceType.icon, color: device.deviceType.color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name, style: AppTypography.titleMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOnline ? AppColors.success : AppColors.textSecondary(isDark).withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: AppTypography.bodySmall.copyWith(
                          color: isOnline ? AppColors.success : AppColors.textSecondary(isDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: AppColors.textSecondary(isDark))),
                      const SizedBox(width: 8),
                      Text(
                        device.deviceType.shortName,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(isDark)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary(isDark)),
          ],
        ),
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  final bool isDark;
  const _EmptyDevices({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.devices_other_outlined, size: 64, color: AppColors.textSecondary(isDark).withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No devices found', style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary(isDark))),
        ],
      ),
    );
  }
}
