import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/device.model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../common/widgets/app_screen_wrapper.dart';
import '../common/widgets/glass_panel.dart';

class DeviceModelDef {
  final String name;
  final String category;
  final IconData icon;
  final DeviceType deviceType;
  final String ssidPattern;
  final int switchCount;

  const DeviceModelDef({
    required this.name,
    required this.category,
    required this.icon,
    required this.deviceType,
    required this.ssidPattern,
    required this.switchCount,
  });
}

class AddDeviceScreen extends ConsumerStatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  ConsumerState<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends ConsumerState<AddDeviceScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Smart Switches',
    'Smart Switches (Non-Touch)',
    'Custom IoT Device',
    'IR Remotes',
    'Energy Monitoring',
    'Environment',
    'Water Systems',
    'Smart Kitchen',
  ];

  final List<DeviceModelDef> _devices = [
    // Smart Switches
    const DeviceModelDef(name: 'Neuro Touch 4S', category: 'Smart Switches', icon: Icons.grid_view_rounded, deviceType: DeviceType.smartSwitch, ssidPattern: 'Neuro_Touch_4S', switchCount: 4),
    const DeviceModelDef(name: 'Neuro Touch 6S', category: 'Smart Switches', icon: Icons.grid_view_rounded, deviceType: DeviceType.smartSwitch, ssidPattern: 'Neuro_Touch_6S', switchCount: 6),
    const DeviceModelDef(name: 'Neuro Touch 8S', category: 'Smart Switches', icon: Icons.grid_view_rounded, deviceType: DeviceType.smartSwitch, ssidPattern: 'Neuro_Touch_8S', switchCount: 8),
    const DeviceModelDef(name: 'Neuro Touch 12S', category: 'Smart Switches', icon: Icons.grid_view_rounded, deviceType: DeviceType.smartSwitch, ssidPattern: 'Neuro_Touch_12S', switchCount: 12),
    const DeviceModelDef(name: 'Neuro Touch 16S', category: 'Smart Switches', icon: Icons.grid_view_rounded, deviceType: DeviceType.smartSwitch, ssidPattern: 'Neuro_Touch_16S', switchCount: 16),

    // Smart Switches (Non-Touch)
    const DeviceModelDef(name: 'Neuro Smart Switch 4S', category: 'Smart Switches (Non-Touch)', icon: Icons.toggle_on_rounded, deviceType: DeviceType.neuroSmartSwitch, ssidPattern: 'Neuro_Smart_Switch_4S', switchCount: 4),
    const DeviceModelDef(name: 'Neuro Smart Switch 6S', category: 'Smart Switches (Non-Touch)', icon: Icons.toggle_on_rounded, deviceType: DeviceType.neuroSmartSwitch, ssidPattern: 'Neuro_Smart_Switch_6S', switchCount: 6),
    const DeviceModelDef(name: 'Neuro Smart Switch 8S', category: 'Smart Switches (Non-Touch)', icon: Icons.toggle_on_rounded, deviceType: DeviceType.neuroSmartSwitch, ssidPattern: 'Neuro_Smart_Switch_8S', switchCount: 8),
    const DeviceModelDef(name: 'Neuro Smart Switch 12S', category: 'Smart Switches (Non-Touch)', icon: Icons.toggle_on_rounded, deviceType: DeviceType.neuroSmartSwitch, ssidPattern: 'Neuro_Smart_Switch_12S', switchCount: 12),
    const DeviceModelDef(name: 'Neuro Smart Switch 16S', category: 'Smart Switches (Non-Touch)', icon: Icons.toggle_on_rounded, deviceType: DeviceType.neuroSmartSwitch, ssidPattern: 'Neuro_Smart_Switch_16S', switchCount: 16),

    // IR Remotes
    const DeviceModelDef(name: 'Smart IR Remote 1X', category: 'IR Remotes', icon: Icons.settings_remote_rounded, deviceType: DeviceType.irRemote, ssidPattern: 'IR_Remote_Smart_1X', switchCount: 0),
    const DeviceModelDef(name: 'Smart IR Remote 1P', category: 'IR Remotes', icon: Icons.settings_remote_rounded, deviceType: DeviceType.irRemote, ssidPattern: 'IR_Remote_Smart_1P', switchCount: 0),

    // Energy Monitoring
    const DeviceModelDef(name: 'Single Phase Energy Meter', category: 'Energy Monitoring', icon: Icons.electric_bolt_rounded, deviceType: DeviceType.energyMeter, ssidPattern: 'Single_Phase_1X', switchCount: 0),
    const DeviceModelDef(name: 'Three Phase Energy Meter', category: 'Energy Monitoring', icon: Icons.electric_bolt_rounded, deviceType: DeviceType.energyMeter, ssidPattern: 'Three_Phase_1X', switchCount: 0),

    // Environment
    const DeviceModelDef(name: 'Temperature Monitor 1T', category: 'Environment', icon: Icons.thermostat_rounded, deviceType: DeviceType.tempMonitor, ssidPattern: 'Temp_Monitor_1T', switchCount: 0),

    // Water Systems
    const DeviceModelDef(name: 'Smart Water Level', category: 'Water Systems', icon: Icons.water_drop_rounded, deviceType: DeviceType.waterLevel, ssidPattern: 'Water_Level_Smart_1X', switchCount: 4),
    const DeviceModelDef(name: 'Water Level Plus', category: 'Water Systems', icon: Icons.water_drop_rounded, deviceType: DeviceType.waterLevel, ssidPattern: 'Water_Level_Plus_1X', switchCount: 4),

    // Custom IoT Device - Touch Panels
    const DeviceModelDef(name: 'Touch Panel 6S', category: 'Custom IoT Device', icon: Icons.settings_input_component_rounded, deviceType: DeviceType.customTouchPanel, ssidPattern: 'Touch_Panel_6S', switchCount: 6),
    const DeviceModelDef(name: 'Touch Panel 7S', category: 'Custom IoT Device', icon: Icons.settings_input_component_rounded, deviceType: DeviceType.customTouchPanel, ssidPattern: 'Touch_Panel_7S', switchCount: 7),
    const DeviceModelDef(name: 'Touch Panel 8S', category: 'Custom IoT Device', icon: Icons.settings_input_component_rounded, deviceType: DeviceType.customTouchPanel, ssidPattern: 'Touch_Panel_8S', switchCount: 8),

    // Smart Kitchen
    const DeviceModelDef(name: 'Gas Stove Controller', category: 'Smart Kitchen', icon: Icons.local_fire_department_rounded, deviceType: DeviceType.gasControl, ssidPattern: 'GasKnob-', switchCount: 0),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DeviceModelDef> get _filteredDevices {
    return _devices.where((d) {
      final matchesCategory = _selectedCategory == 'All' || d.category == _selectedCategory;
      final matchesSearch = d.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            _buildHeader(context),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildSearchBar(isDark),
            ),
            
            const Divider(height: 1, thickness: 0.5),
            
            // Main Content: Sidebar + Grid
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sidebar
                  _buildSidebar(isDark),
                  
                  const VerticalDivider(width: 1, thickness: 0.5),
                  
                  // Device Grid
                  Expanded(
                    child: _buildDeviceGrid(isDark),
                  ),
                ],
              ),
            ),
            
            // Bottom Action
            _buildBottomAction(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text('Back', style: TextStyle(color: AppColors.primaryLight)),
          ),
          Text(
            '1. Select Device Type',
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(12),
      opacity: 0.05,
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: const InputDecoration(
          hintText: 'Search Device Types',
          prefixIcon: Icon(Icons.search_rounded, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSidebar(bool isDark) {
    return Container(
      width: 120,
      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
      child: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: isSelected ? Border(left: BorderSide(color: AppColors.primary, width: 3)) : null,
                color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
              ),
              child: Text(
                cat,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary(isDark),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeviceGrid(bool isDark) {
    final devices = _filteredDevices;
    
    if (devices.isEmpty) {
      return Center(
        child: Text(
          'No devices found',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(isDark)),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return _buildDeviceCard(device, isDark);
      },
    );
  }

  Widget _buildDeviceCard(DeviceModelDef device, bool isDark) {
    return GestureDetector(
      onTap: () => context.push(
        '/add-device/provisioning',
        extra: {
          'deviceType': device.deviceType,
          'ssidPattern': device.ssidPattern,
          'switchCount': device.switchCount,
          'deviceName': device.name,
        },
      ),
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(device.icon, color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              device.name,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: TextButton(
        onPressed: null, // Disabled in this stage
        child: Text(
          'Next',
          style: AppTypography.titleMedium.copyWith(color: Colors.grey.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
