import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/dashboard.controller.dart';
import '../../controllers/mqtt.controller.dart';
import '../../controllers/auth.controller.dart';
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
                  _SummarySection(onlineCount: onlineCount, totalWatts: totalWatts),
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

class _DashboardAppBar extends StatelessWidget {
  final dynamic user;
  const _DashboardAppBar({required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return SliverAppBar(
      expandedHeight: 120,
      collapsedHeight: 80,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: user?.profilePictureUrl != null ? NetworkImage(user.profilePictureUrl) : null,
                  child: user?.profilePictureUrl == null
                      ? Text(user?.name.initials ?? '?', style: AppTypography.h3.copyWith(color: AppColors.primary))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(DateTime.now().greeting, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(isDark))),
                      Text(user?.name.split(' ').first ?? 'Home', style: AppTypography.h2),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: GlassPanel(
                    width: 44,
                    height: 44,
                    borderRadius: BorderRadius.circular(12),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final int onlineCount;
  final double totalWatts;

  const _SummarySection({required this.onlineCount, required this.totalWatts});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryCard(label: 'Online', value: '$onlineCount', icon: Icons.wifi_tethering_rounded, color: AppColors.success),
        const SizedBox(width: 12),
        _SummaryCard(label: 'Usage', value: totalWatts.toWattsString, icon: Icons.electric_bolt_rounded, color: AppColors.warning),
        const SizedBox(width: 12),
        _SummaryCard(label: 'Auto', value: '12', icon: Icons.auto_awesome_rounded, color: AppColors.primaryLight),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Expanded(
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value, style: AppTypography.h3),
            Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(isDark))),
          ],
        ),
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
