import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/dashboard.controller.dart';
import '../../controllers/mqtt.controller.dart';
import '../../controllers/auth.controller.dart';
import '../../data/models/device.model.dart';
import '../../data/models/room.model.dart';
import '../../core/utils/extensions.dart';

const Color _primary = Color(0xFF4C6FFF);
const Color _secondary = Color(0xFF6C5CE7);
const Color _darkBg = Color(0xFF010817);
const Color _cardDark = Color(0xFF45484D);
const Color _error = Color(0xFFE17055);
const Color _darkTextPrimary = Color(0xFFFFFFFF);
const Color _darkTextSecondary = Color(0xFFB2BEC3);
const Color _lightTextPrimary = Color(0xFF0F172A);
const Color _lightTextSecondary = Color(0xFF555E68);
const Color _borderDark = Color(0xFF55595E);
const Color _borderLight = Color(0xFFD1D5DB);
const Color _online = Color(0xFF00B894);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  Future<void> _loadDashboard() async {
    final homeId = ref.read(homeIdProvider);
    if (homeId != null) {
      await ref
          .read(dashboardControllerProvider.notifier)
          .loadDashboard(homeId);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final screenSize = MediaQuery.sizeOf(context);
    final dashState = ref.watch(dashboardControllerProvider);
    final mqttState = ref.watch(mqttControllerProvider);
    final user = ref.watch(currentUserProvider);

    final bgColor = isDark ? _darkBg : Colors.white;
    final textPrimary = isDark ? _darkTextPrimary : _lightTextPrimary;
    final textSecondary = isDark ? _darkTextSecondary : _lightTextSecondary;

    final onlineCount =
        dashState.devices.where((d) => mqttState.isDeviceOnline(d.id)).length;

    final totalWatts = dashState.devices
        .map((d) => mqttState.getWatts(d.id))
        .fold<double>(0.0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        color: _primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: bgColor,
              elevation: 0,
              scrolledUnderElevation: 0,
              expandedHeight: screenSize.height * 0.12,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: EdgeInsets.fromLTRB(
                    screenSize.width * 0.05,
                    MediaQuery.paddingOf(context).top + 12,
                    screenSize.width * 0.05,
                    8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateTime.now().greeting,
                              style: GoogleFonts.inter(
                                color: textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.name.split(' ').first ?? 'Welcome',
                              style: GoogleFonts.inter(
                                color: textPrimary,
                                fontSize: screenSize.width * 0.055,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Notification bell
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: Icon(Icons.notifications_outlined,
                                color: textPrimary, size: 26),
                            onPressed: () =>
                                context.go('/automation', extra: 'alerts'),
                          ),
                          if (dashState.notificationCount > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: _error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Avatar
                      GestureDetector(
                        onTap: () => context.go('/settings/profile'),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: _primary.withOpacity(0.15),
                          child: Text(
                            (user?.name.initials) ?? '?',
                            style: GoogleFonts.inter(
                              color: _primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Floor / Room Filter
                    _FloorRoomFilter(isDark: isDark),

                    const SizedBox(height: 16),

                    // Summary Row
                    _SummaryRow(
                      onlineCount: onlineCount,
                      totalWatts: totalWatts,
                      automationCount: 0,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 20),

                    // Rooms header
                    Text(
                      'Rooms',
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Room Cards
                    if (dashState.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (dashState.filteredRooms.isEmpty)
                      _EmptyRooms(isDark: isDark)
                    else
                      SizedBox(
                        height: screenSize.height * 0.22,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: dashState.filteredRooms.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, index) {
                            final room = dashState.filteredRooms[index];
                            final roomDevices =
                                dashState.devicesInRoom(room.id);
                            return _RoomCard(
                              room: room,
                              deviceCount: roomDevices.length,
                              isDark: isDark,
                              screenWidth: screenSize.width,
                              onTap: () => ref
                                  .read(dashboardControllerProvider.notifier)
                                  .selectRoom(room.id),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Devices header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Devices',
                          style: GoogleFonts.inter(
                            color: textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/devices'),
                          child: Text(
                            'See all',
                            style: GoogleFonts.inter(
                                color: _primary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Device list
                    if (dashState.isLoading)
                      const SizedBox.shrink()
                    else if (dashState.filteredDevices.isEmpty)
                      _EmptyDevices(isDark: isDark)
                    else
                      Column(
                        children: dashState.filteredDevices
                            .take(8)
                            .map((device) => _DeviceListItem(
                                  device: device,
                                  isDark: isDark,
                                  onTap: () =>
                                      context.push('/devices/${device.id}'),
                                ))
                            .toList(),
                      ),

                    // Bottom padding for nav bar
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----- Floor / Room Filter -----

class _FloorRoomFilter extends ConsumerWidget {
  final bool isDark;
  const _FloorRoomFilter({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    final chipBg = isDark ? _cardDark : const Color(0xFFF5F5F5);
    final selectedBg = _primary;
    final chipText = isDark ? _darkTextSecondary : _lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Floors
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.floors.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              if (index == 0) {
                final isSelected = state.selectedFloorId == null;
                return _FilterPill(
                  label: 'All',
                  isSelected: isSelected,
                  onTap: () => controller.selectFloor(null),
                  selectedBg: selectedBg,
                  unselectedBg: chipBg,
                  selectedText: Colors.white,
                  unselectedText: chipText,
                );
              }
              final floor = state.floors[index - 1];
              final isSelected = state.selectedFloorId == floor.id;
              return _FilterPill(
                label: floor.name,
                isSelected: isSelected,
                onTap: () => controller.selectFloor(floor.id),
                selectedBg: selectedBg,
                unselectedBg: chipBg,
                selectedText: Colors.white,
                unselectedText: chipText,
              );
            },
          ),
        ),

        // Rooms (animated)
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: state.selectedFloorId != null &&
                  state.filteredRooms.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.filteredRooms.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        if (index == 0) {
                          final isSelected = state.selectedRoomId == null;
                          return _FilterPill(
                            label: 'All Rooms',
                            isSelected: isSelected,
                            onTap: () => controller.selectRoom(null),
                            selectedBg: _secondary,
                            unselectedBg: chipBg,
                            selectedText: Colors.white,
                            unselectedText: chipText,
                          );
                        }
                        final room = state.filteredRooms[index - 1];
                        final isSelected = state.selectedRoomId == room.id;
                        return _FilterPill(
                          label: room.name,
                          isSelected: isSelected,
                          onTap: () => controller.selectRoom(room.id),
                          selectedBg: _secondary,
                          unselectedBg: chipBg,
                          selectedText: Colors.white,
                          unselectedText: chipText,
                        );
                      },
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedBg;
  final Color unselectedBg;
  final Color selectedText;
  final Color unselectedText;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.selectedBg,
    required this.unselectedBg,
    required this.selectedText,
    required this.unselectedText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? selectedText : unselectedText,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ----- Summary Row -----

class _SummaryRow extends StatelessWidget {
  final int onlineCount;
  final double totalWatts;
  final int automationCount;
  final bool isDark;

  const _SummaryRow({
    required this.onlineCount,
    required this.totalWatts,
    required this.automationCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryCard(
          icon: Icons.devices_other_rounded,
          iconColor: _primary,
          label: 'Online',
          value: '$onlineCount',
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _SummaryCard(
          icon: Icons.electric_bolt_rounded,
          iconColor: const Color(0xFF00B894),
          label: 'Total Load',
          value: totalWatts.toWattsString,
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _SummaryCard(
          icon: Icons.auto_awesome_rounded,
          iconColor: _secondary,
          label: 'Automations',
          value: '$automationCount',
          isDark: isDark,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? _cardDark : const Color(0xFF194B85);
    final textPrimary = isDark ? _darkTextPrimary : Colors.white;
    final textSecondary = isDark ? _darkTextSecondary : Colors.white70;
    final finalIconColor = isDark ? iconColor : Colors.white;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? _borderDark : _borderLight,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: finalIconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: finalIconColor, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                color: textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----- Room Card -----

class _RoomCard extends ConsumerWidget {
  final RoomModel room;
  final int deviceCount;
  final bool isDark;
  final double screenWidth;
  final VoidCallback onTap;

  const _RoomCard({
    required this.room,
    required this.deviceCount,
    required this.isDark,
    required this.screenWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finalCardColor = isDark ? null : const Color(0xFF194B85);
    final finalIconColor = isDark ? _primary : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: screenWidth * 0.42,
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [_cardDark, Color(0xFF010817)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: finalCardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? _borderDark : _borderLight,
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: finalIconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getRoomIcon(room.icon), color: finalIconColor, size: 24),
            ),
            const Spacer(),
            Text(
              room.name,
              style: GoogleFonts.inter(
                color: isDark ? _darkTextPrimary : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '$deviceCount devices',
              style: GoogleFonts.inter(
                color: isDark ? _darkTextSecondary : Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRoomIcon(String icon) {
    switch (icon.toLowerCase()) {
      case 'bedroom': return Icons.bed_outlined;
      case 'kitchen': return Icons.kitchen_outlined;
      case 'bathroom': return Icons.shower_outlined;
      case 'garage': return Icons.garage_outlined;
      case 'office': return Icons.computer_outlined;
      case 'living': return Icons.chair_outlined;
      case 'dining': return Icons.dining_outlined;
      case 'garden': return Icons.yard_outlined;
      default: return Icons.room_outlined;
    }
  }
}

// ----- Device List Item -----

class _DeviceListItem extends ConsumerWidget {
  final DeviceModel device;
  final bool isDark;
  final VoidCallback onTap;

  const _DeviceListItem({
    required this.device,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(deviceOnlineProvider(device.id));
    final cardColor = isDark ? _cardDark : const Color(0xFF194B85);
    final textPrimary = isDark ? _darkTextPrimary : Colors.white;
    final textSecondary = isDark ? _darkTextSecondary : Colors.white70;
    final iconColor = isDark ? device.deviceType.color : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            // Device type icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                device.deviceType.icon,
                color: iconColor,
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            // Name + type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: GoogleFonts.inter(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.deviceType.shortName,
                    style: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Online indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isOnline)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.7, end: 1.1),
                    duration: const Duration(milliseconds: 800),
                    builder: (_, scale, child) => Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _online,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF555E68),
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(height: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: textSecondary,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  final bool isDark;
  const _EmptyRooms({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.room_outlined,
              color: isDark ? _darkTextSecondary : _lightTextSecondary, size: 32),
          const SizedBox(height: 8),
          Text(
            'No rooms configured yet',
            style: GoogleFonts.inter(
              color: isDark ? _darkTextSecondary : _lightTextSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  final bool isDark;
  const _EmptyDevices({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.devices_other_outlined,
              color: isDark ? _darkTextSecondary : _lightTextSecondary, size: 40),
          const SizedBox(height: 12),
          Text(
            'No devices found',
            style: GoogleFonts.inter(
              color: isDark ? _darkTextPrimary : _lightTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add your first device',
            style: GoogleFonts.inter(
              color: isDark ? _darkTextSecondary : _lightTextSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
