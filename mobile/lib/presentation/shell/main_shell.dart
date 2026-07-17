import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/dashboard.controller.dart';
import '../../controllers/mqtt.controller.dart';

const Color _primary = Color(0xFF4C6FFF);
const Color _secondary = Color(0xFF6C5CE7);
const Color _darkBg = Color(0xFF010817);
const Color _lightBg = Color(0xFF194B85); // Deep blue bar background in Light Mode
const Color _darkTextSecondary = Color(0xFFB2BEC3);
const Color _lightTextSecondary = Colors.white60; // Light secondary color for unselected items
const Color _borderDark = Color(0xFF55595E);
const Color _borderLight = Color(0xFF103560);
const Color _error = Color(0xFFE17055);

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
    // Connect MQTT after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mqttControllerProvider.notifier).connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = widget.navigationShell.currentIndex;
    final notifCount =
        ref.watch(dashboardControllerProvider).notificationCount;

    return Scaffold(
      body: widget.navigationShell,
      extendBody: true,
      bottomNavigationBar: _BottomNav(
        currentIndex: currentIndex,
        notifCount: notifCount,
        isDark: isDark,
        onTap: (index) {
          if (index == 2) return; // FAB placeholder
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == currentIndex,
          );
        },
      ),
      floatingActionButton: _CenterFAB(
        onTap: () => context.push('/add-device'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primary, _secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final int notifCount;
  final bool isDark;
  final Function(int) onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.notifCount,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? _darkBg : _lightBg;
    final borderColor = isDark ? _borderDark : _borderLight;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                index: 0,
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                currentIndex: currentIndex,
                notifCount: notifCount,
                isDark: isDark,
                onTap: onTap,
              ),
              _NavItem(
                index: 1,
                icon: Icons.devices_other_outlined,
                selectedIcon: Icons.devices_other_rounded,
                currentIndex: currentIndex,
                isDark: isDark,
                onTap: onTap,
              ),
              const Expanded(child: SizedBox()), // FAB center space
              _NavItem(
                index: 3,
                icon: Icons.bolt_outlined,
                selectedIcon: Icons.bolt_rounded,
                currentIndex: currentIndex,
                isDark: isDark,
                onTap: onTap,
              ),
              _NavItem(
                index: 4,
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
                currentIndex: currentIndex,
                isDark: isDark,
                onTap: onTap,
              ),
            ],
          ),
        ),
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
  final bool isDark;
  final Function(int) onTap;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
    this.notifCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentIndex == index;
    final color = isSelected
        ? _primary
        : (isDark ? _darkTextSecondary : _lightTextSecondary);

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    isSelected ? selectedIcon : icon,
                    key: ValueKey('${index}_$isSelected'),
                    color: color,
                    size: 26,
                  ),
                ),
                if (notifCount > 0 && index == 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: _error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        notifCount > 9 ? '9+' : '$notifCount',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 4 : 0,
              height: isSelected ? 4 : 0,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
