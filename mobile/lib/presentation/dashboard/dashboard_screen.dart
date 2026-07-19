import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/dashboard.controller.dart';
import '../../controllers/mqtt.controller.dart';
import '../../controllers/auth.controller.dart';
import '../../controllers/home_setup.controller.dart';
import '../../data/models/device.model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../common/widgets/glass_panel.dart';
import '../common/widgets/app_section_header.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  Future<void> _loadDashboard() async {
    final homeId = ref.read(homeIdProvider);
    if (homeId != null) {
      await ref.read(dashboardControllerProvider.notifier).loadDashboard(homeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardControllerProvider);
    final mqttState = ref.watch(mqttControllerProvider);
    final user = ref.watch(currentUserProvider);
    final isDark = context.isDark;

    final onlineCount = dashState.devices.where((d) => mqttState.isDeviceOnline(d.id)).length;
    final totalWatts = dashState.devices.map((d) => mqttState.getWatts(d.id)).fold<double>(0.0, (a, b) => a + b);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _DashboardAppBar(user: user),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 24),
                  _RunningHoursSection(dashState: dashState, totalWatts: totalWatts),
                  const SizedBox(height: 32),
                  AppSectionHeader(
                    title: 'Active Devices',
                    actionLabel: 'See all',
                    onActionPressed: () => context.go('/devices'),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  _DeviceSection(dashState: dashState),
                  const SizedBox(height: 120), // Bottom nav padding
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardAppBar extends ConsumerWidget {
  final dynamic user;
  const _DashboardAppBar({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final homesAsync = ref.watch(userHomesProvider);
    final selectedHomeId = ref.watch(homeIdProvider);
    
    return SliverAppBar(
      expandedHeight: 90,
      collapsedHeight: 75,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: GlassPanel(
              color: isDark ? null : AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              borderRadius: BorderRadius.circular(40),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isDark ? AppColors.primary.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.2),
                    backgroundImage: user?.profilePictureUrl != null ? NetworkImage(user.profilePictureUrl) : null,
                    child: user?.profilePictureUrl == null
                        ? Text(user?.name.initials ?? '?', style: AppTypography.h3.copyWith(color: isDark ? AppColors.primary : Colors.white))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateTime.now().greeting, style: AppTypography.bodySmall.copyWith(color: isDark ? AppColors.textSecondary(isDark) : Colors.white70)),
                        Text(user?.name.split(' ').first ?? 'Home', style: AppTypography.h2.copyWith(color: isDark ? null : Colors.white)),
                      ],
                    ),
                  ),
                  homesAsync.when(
                    data: (homes) {
                      if (homes.isEmpty) return const SizedBox();
                      if (homes.length == 1) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            homes.first.name,
                            style: AppTypography.titleMedium.copyWith(color: isDark ? null : Colors.white),
                          ),
                        );
                      }
                      
                      final selectedHome = homes.firstWhere(
                        (h) => h.id == selectedHomeId, 
                        orElse: () => homes.first,
                      );
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.primary.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedHome.id,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded, 
                              size: 18, 
                              color: Colors.white,
                            ),
                            isDense: true,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: AppColors.scaffoldBackground(isDark),
                            items: homes.map((home) {
                              return DropdownMenuItem<String>(
                                value: home.id,
                                child: Text(
                                  home.name, 
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: isDark ? AppColors.textPrimary(isDark) : Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (newId) {
                              if (newId != null && newId != selectedHomeId) {
                                ref.read(homeIdProvider.notifier).state = newId;
                                ref.read(dashboardControllerProvider.notifier).loadDashboard(newId);
                              }
                            },
                          ),
                        ),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.only(right: 12.0),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunningHoursSection extends StatefulWidget {
  final dynamic dashState;
  final double totalWatts;
  const _RunningHoursSection({required this.dashState, required this.totalWatts});

  @override
  State<_RunningHoursSection> createState() => _RunningHoursSectionState();
}

class _RunningHoursSectionState extends State<_RunningHoursSection> {
  final List<String> _rooms = []; 
  String? _selectedRoom;
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    _initializeDefaultDevice();
  }

  @override
  void didUpdateWidget(covariant _RunningHoursSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedDeviceId == null) {
      _initializeDefaultDevice();
    }
  }

  void _initializeDefaultDevice() {
    if (widget.dashState.devices.isNotEmpty) {
      _selectedDeviceId = widget.dashState.devices.first.id;
    }
  }

  int _getMockRunningHours(String? deviceId, String? roomName) {
    if (deviceId == null) return 0;
    return ((deviceId.hashCode ^ (roomName?.hashCode ?? 0)).abs() % 500) + 24;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final availableDevices = widget.dashState.devices as List<dynamic>;
    
    if (availableDevices.isNotEmpty && !availableDevices.any((d) => d.id == _selectedDeviceId)) {
      _selectedDeviceId = availableDevices.first.id;
    }

    final hours = _getMockRunningHours(_selectedDeviceId, _selectedRoom);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GlassPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Running Hours', style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary(isDark))),
                Icon(Icons.query_stats_rounded, color: AppColors.textSecondary(isDark), size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _rooms.isEmpty
                      ? _buildDropdown(
                          value: 'No Rooms',
                          items: ['No Rooms'],
                          onChanged: null,
                          icon: Icons.meeting_room_rounded,
                          isDark: isDark,
                        )
                      : _buildDropdown(
                          value: _selectedRoom,
                          items: _rooms,
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedRoom = val);
                          },
                          icon: Icons.meeting_room_rounded,
                          isDark: isDark,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: availableDevices.isEmpty
                      ? _buildDropdown(
                          value: 'No Devices',
                          items: ['No Devices'],
                          onChanged: null,
                          icon: Icons.devices_rounded,
                          isDark: isDark,
                        )
                      : _buildDropdown(
                          value: _selectedDeviceId,
                          items: availableDevices.map((d) => d.id.toString()).toList(),
                          labels: availableDevices.map((d) => d.name.toString()).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDeviceId = val);
                          },
                          icon: Icons.devices_rounded,
                          isDark: isDark,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$hours',
                          style: AppTypography.h1.copyWith(
                            color: AppColors.primary,
                            fontSize: 48,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('hrs', style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary(isDark))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.electric_bolt_rounded, size: 16, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.totalWatts.toWattsString} Usage', 
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(isDark), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.schedule_rounded, color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.primary.withValues(alpha: 0.1), size: 56),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    List<String>? labels,
    required void Function(String?)? onChanged,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor(isDark), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                isDense: false,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary(isDark), size: 18),
                dropdownColor: AppColors.scaffoldBackground(isDark),
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary(isDark)),
                onChanged: onChanged,
                items: List.generate(items.length, (index) {
                  return DropdownMenuItem(
                    value: items[index],
                    child: Text(
                      labels != null ? labels[index] : items[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceSection extends StatelessWidget {
  final dynamic dashState;
  const _DeviceSection({required this.dashState});

  @override
  Widget build(BuildContext context) {
    if (dashState.devices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.devices_other_rounded, size: 52, color: AppColors.textSecondary(context.isDark).withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(
                'No devices yet',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary(context.isDark),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add a device to get started',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary(context.isDark).withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: dashState.devices.take(6).map<Widget>((device) => _DeviceListItem(device: device)).toList(),
    );
  }
}

class _DeviceListItem extends ConsumerWidget {
  final DeviceModel device;
  const _DeviceListItem({required this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(deviceOnlineProvider(device.id));
    final isDark = context.isDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: device.deviceType.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(device.deviceType.icon, color: device.deviceType.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name, style: AppTypography.titleSmall),
                  Text(device.deviceType.shortName, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(isDark))),
                ],
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: isOnline ? AppColors.success : AppColors.textSecondary(isDark).withValues(alpha: 0.3), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
