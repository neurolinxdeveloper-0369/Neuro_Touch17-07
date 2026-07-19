import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../common/widgets/app_screen_wrapper.dart';
import '../common/widgets/glass_panel.dart';

class DeviceModelDef {
  final String name;
  final String category;
  final IconData icon;
  final int? panelNumber; // Only set for Touch Panel variants

  const DeviceModelDef({
    required this.name,
    required this.category,
    required this.icon,
    this.panelNumber,
  });
}

class AddDeviceScreen extends ConsumerStatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  ConsumerState<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends ConsumerState<AddDeviceScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'IR Blasters',
    'Touch Switches',
    'Energy Meters',
    'Sensors',
    'Water Systems',
    'Custom IoT Device',
  ];

  final List<DeviceModelDef> _devices = [
    // IR Blasters
    const DeviceModelDef(name: 'Smart IR', category: 'IR Blasters', icon: Icons.sensors_rounded),
    const DeviceModelDef(name: 'IR Blaster Plus', category: 'IR Blasters', icon: Icons.sensors_rounded),
    
    // Touch Switches
    const DeviceModelDef(name: '1 Node Touch Switch', category: 'Touch Switches', icon: Icons.touch_app_rounded),
    const DeviceModelDef(name: '2 Node Touch Switch', category: 'Touch Switches', icon: Icons.touch_app_rounded),
    const DeviceModelDef(name: '4 Node Touch Switch', category: 'Touch Switches', icon: Icons.touch_app_rounded),
    const DeviceModelDef(name: '6 Node Touch Switch', category: 'Touch Switches', icon: Icons.touch_app_rounded),
    const DeviceModelDef(name: '8 Node Touch Switch', category: 'Touch Switches', icon: Icons.touch_app_rounded),
    const DeviceModelDef(name: '10 Node Touch Switch', category: 'Touch Switches', icon: Icons.touch_app_rounded),
    const DeviceModelDef(name: '16 Node Touch Switch', category: 'Touch Switches', icon: Icons.touch_app_rounded),
    
    // Energy Meters
    const DeviceModelDef(name: '1 Switch (Single Phase)', category: 'Energy Meters', icon: Icons.electric_bolt_rounded),
    const DeviceModelDef(name: '1 Switch (Three Phase)', category: 'Energy Meters', icon: Icons.electric_bolt_rounded),
    const DeviceModelDef(name: 'Single Phase Energy Meter', category: 'Energy Meters', icon: Icons.speed_rounded),
    const DeviceModelDef(name: 'Three Phase Energy Meter', category: 'Energy Meters', icon: Icons.speed_rounded),
    
    // Sensors
    const DeviceModelDef(name: 'Sensor Smart (Temp)', category: 'Sensors', icon: Icons.thermostat_rounded),
    
    // Water Systems
    const DeviceModelDef(name: 'Smart Water Tank Controller', category: 'Water Systems', icon: Icons.water_drop_rounded),
    const DeviceModelDef(name: 'Water Tank Controller Plus', category: 'Water Systems', icon: Icons.water_drop_rounded),

    // Custom IoT Device — Touch Panels (panelNumber drives switch count & SSID validation)
    const DeviceModelDef(name: 'Touch Panel - 6', category: 'Custom IoT Device', icon: Icons.settings_input_component_rounded, panelNumber: 6),
    const DeviceModelDef(name: 'Touch Panel - 7', category: 'Custom IoT Device', icon: Icons.settings_input_component_rounded, panelNumber: 7),
    const DeviceModelDef(name: 'Touch Panel - 8', category: 'Custom IoT Device', icon: Icons.settings_input_component_rounded, panelNumber: 8),
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
        decoration: InputDecoration(
          hintText: 'Search Device Types',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
        extra: {'panelNumber': device.panelNumber ?? 6},
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
