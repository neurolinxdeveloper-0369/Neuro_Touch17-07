import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../common/widgets/app_screen_wrapper.dart';

class AutomationScreen extends ConsumerStatefulWidget {
  const AutomationScreen({super.key});

  @override
  ConsumerState<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends ConsumerState<AutomationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return AppScreenWrapper(
      title: 'Automation',
      scrollable: false,
      actions: [
        IconButton(
          onPressed: () => context.push('/automation/chat'),
          icon: const Icon(Icons.auto_awesome_outlined),
        ),
      ],

      child: Column(
        children: [
          TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary(isDark),
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: AppTypography.bodySmall,
            tabs: const [
              Tab(text: 'Scenes'),
              Tab(text: 'Schedules'),
              Tab(text: 'Alerts'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _EmptyTab(
                  icon: Icons.auto_awesome_rounded,
                  title: 'No scenes yet',
                  subtitle: 'Create smart scenarios to control multiple devices',
                  isDark: isDark,
                ),
                _EmptyTab(
                  icon: Icons.schedule_rounded,
                  title: 'No schedules yet',
                  subtitle: 'Automate your home based on the time of day',
                  isDark: isDark,
                ),
                _EmptyTab(
                  icon: Icons.notifications_none_rounded,
                  title: 'No active alerts',
                  subtitle: 'Stay notified about your home status',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _EmptyTab({required this.icon, required this.title, required this.subtitle, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textSecondary(isDark).withValues(alpha: 0.2)),
          const SizedBox(height: 24),
          Text(title, style: AppTypography.h3),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(isDark)),
          ),
        ],
      ),
    );
  }
}
