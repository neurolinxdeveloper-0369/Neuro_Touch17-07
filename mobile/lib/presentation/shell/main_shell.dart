  import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/dashboard.controller.dart';
import '../../controllers/mqtt.controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mqttControllerProvider.notifier).connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final notifCount = ref.watch(dashboardControllerProvider).notificationCount;
    final isWide = context.isTablet || context.isDesktop;

    // Check if the current branch's navigator can pop internally
    final bool canPopInternally = false;

    return PopScope(
      canPop: canPopInternally || currentIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // If we couldn't pop (meaning we are at the root of a non-home tab), go back to home tab
        widget.navigationShell.goBranch(0);
      },
      child: Scaffold(
        extendBody: true,
        body: Row(
          children: [
            if (isWide)
              _SideRail(
                currentIndex: currentIndex,
                onTap: _onTap,
                onAddTap: () => context.push('/add-device'),
              ),
            Expanded(child: widget.navigationShell),
          ],
        ),
        bottomNavigationBar: isWide
            ? null
            : _BottomNav(
                currentIndex: currentIndex,
                notifCount: notifCount,
                onTap: _onTap,
                onAddTap: () => context.push('/add-device'),
              ),
      ),
    );
  }

  void _onTap(int index) {
    if (index == 2) return;
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}

class _SideRail extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onAddTap;

  const _SideRail({
    required this.currentIndex,
    required this.onTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground(isDark),
        border: Border(right: BorderSide(color: AppColors.borderColor(isDark), width: 0.5)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          _CenterFAB(onTap: onAddTap),
          const SizedBox(height: 40),
          Expanded(
            child: ListView(
              children: [
                _RailItem(index: 0, icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, currentIndex: currentIndex, onTap: onTap),
                _RailItem(index: 1, icon: Icons.devices_outlined, selectedIcon: Icons.devices_rounded, currentIndex: currentIndex, onTap: onTap),
                _RailItem(index: 3, icon: Icons.auto_awesome_outlined, selectedIcon: Icons.auto_awesome_rounded, currentIndex: currentIndex, onTap: onTap),
                _RailItem(index: 4, icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, currentIndex: currentIndex, onTap: onTap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final int currentIndex;
  final Function(int) onTap;

  const _RailItem({required this.index, required this.icon, required this.selectedIcon, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = currentIndex == index;
    final color = isSelected ? AppColors.primary : Colors.white;

    return IconButton(
      onPressed: () => onTap(index),
      icon: Icon(isSelected ? selectedIcon : icon, color: color, size: 26),
      padding: const EdgeInsets.symmetric(vertical: 20),
    );
  }
}

class _CenterFAB extends StatelessWidget {
  final VoidCallback onTap;

  const _CenterFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 36),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final int notifCount;
  final Function(int) onTap;
  final VoidCallback onAddTap;

  const _BottomNav({
    required this.currentIndex,
    required this.notifCount,
    required this.onTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    
    // Calculate adaptive bottom margin
    final double finalBottomPadding = bottomPadding > 0 ? bottomPadding + 8 : 20;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, finalBottomPadding),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            _NavItem(index: 0, icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, currentIndex: currentIndex, notifCount: notifCount, onTap: onTap),
            _NavItem(index: 1, icon: Icons.devices_outlined, selectedIcon: Icons.devices_rounded, currentIndex: currentIndex, onTap: onTap),
            Expanded(
              child: _CenterAddButton(onTap: onAddTap),
            ),
            _NavItem(index: 3, icon: Icons.auto_awesome_outlined, selectedIcon: Icons.auto_awesome_rounded, currentIndex: currentIndex, onTap: onTap),
            _NavItem(index: 4, icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, currentIndex: currentIndex, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _CenterAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CenterAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF121212),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final int currentIndex;
  final int notifCount;
  final Function(int) onTap;

  const _NavItem({required this.index, required this.icon, required this.selectedIcon, required this.currentIndex, required this.onTap, this.notifCount = 0});

  @override
  Widget build(BuildContext context) {
    final isSelected = currentIndex == index;
    final isDark = context.isDark;
    final color = isSelected ? AppColors.primary : (isDark ? Colors.white : Colors.black87);

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(isSelected ? selectedIcon : icon, color: color, size: 24),
            if (notifCount > 0 && index == 0)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  child: Text('$notifCount', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
