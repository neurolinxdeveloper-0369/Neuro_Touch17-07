import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/extensions.dart';
import '../../../controllers/dashboard.controller.dart';
import '../../../controllers/mqtt.controller.dart';
import '../../common/widgets/glass_panel.dart';

// State Provider for Room Filter
final selectedRoomProvider = StateProvider<String>((ref) => 'All');

// 1. Smart Alerts Banner
class SmartAlertsSection extends ConsumerWidget {
  final dynamic dashState;
  const SmartAlertsSection({super.key, required this.dashState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mqttState = ref.watch(mqttControllerProvider);
    final isDark = context.isDark;

    // Detect offline devices or devices running too long
    List<String> alerts = [];
    int offlineCount = 0;
    
    for (var device in dashState.devices) {
      if (!mqttState.isDeviceOnline(device.id)) {
        offlineCount++;
      } else if (device.deviceType.name.contains('motor')) {
        // Just mock long running motor logic if it's ON
        bool isAnySwitchOn = false;
        for (int i = 1; i <= device.switchCount; i++) {
          if (mqttState.getSwitchState(device.id, i)) {
            isAnySwitchOn = true;
            break;
          }
        }
        if (isAnySwitchOn) {
          alerts.add('${device.name} running unusually long. [Tap to check]');
        }
      }
    }

    if (offlineCount > 0) {
      alerts.add('$offlineCount devices are currently offline.');
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
              ? [const Color(0xFF3F2A1D), const Color(0xFF2A1C14)] 
              : [const Color(0xFFFFF4E5), const Color(0xFFFFE0B2)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.orangeAccent.withOpacity(0.3) : Colors.orangeAccent.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: isDark ? Colors.orangeAccent : Colors.deepOrange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                alerts.first,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark ? Colors.orange[100] : Colors.deepOrange[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 20, color: isDark ? Colors.orange[200] : Colors.deepOrange[800]),
              onPressed: () {}, // Mock dismiss
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            )
          ],
        ),
      ),
    );
  }
}

// 2. Quick Scenes Section
class ScenesSection extends StatelessWidget {
  const ScenesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    final scenes = [
      {'title': 'Good Morning', 'icon': Icons.wb_sunny_rounded, 'color': Colors.amber},
      {'title': 'Leaving Home', 'icon': Icons.directions_run_rounded, 'color': Colors.blueAccent},
      {'title': 'Good Night', 'icon': Icons.nights_stay_rounded, 'color': Colors.indigo},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Quick Scenes',
            style: AppTypography.titleMedium.copyWith(
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: scenes.length,
            itemBuilder: (context, index) {
              final scene = scenes[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: (scene['color'] as Color).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: (scene['color'] as Color).withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      // Trigger scene (mock)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Triggered ${scene['title']} scene')),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(scene['icon'] as IconData, color: scene['color'] as Color, size: 28),
                          const Spacer(),
                          Text(
                            scene['title'] as String,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// 3. Room Filters Row
class RoomFilterRow extends ConsumerWidget {
  final dynamic dashState;
  const RoomFilterRow({super.key, required this.dashState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRoom = ref.watch(selectedRoomProvider);
    final isDark = context.isDark;

    // Extract unique rooms
    Set<String> roomsSet = {'All'};
    for (var device in dashState.devices) {
      if (device.roomId != null && device.roomId!.isNotEmpty) {
        roomsSet.add(device.roomId!);
      } else {
        roomsSet.add(device.assignmentType.toUpperCase()); // Mock room if none
      }
    }
    
    // Hardcode some defaults if none exist
    if (roomsSet.length == 1) {
      roomsSet.addAll(['Living Room', 'Kitchen', 'Bedroom']);
    }

    final rooms = roomsSet.toList();

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          final isSelected = room == selectedRoom;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(room),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  ref.read(selectedRoomProvider.notifier).state = room;
                }
              },
              selectedColor: AppColors.primary,
              backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }
}
