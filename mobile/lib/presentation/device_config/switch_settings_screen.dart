import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../data/models/device.model.dart';
import '../../data/repositories/device.repository.dart';
import '../../controllers/dashboard.controller.dart';

class ApplianceTypeInfo {
  final String id;
  final String name;
  final IconData icon;

  const ApplianceTypeInfo(this.id, this.name, this.icon);
}

const List<ApplianceTypeInfo> applianceTypes = [
  ApplianceTypeInfo('lightbulb', 'Light', Icons.lightbulb_outline),
  ApplianceTypeInfo('fan', 'Fan', Icons.wind_power),
  ApplianceTypeInfo('ac', 'Air Conditioner', Icons.ac_unit),
  ApplianceTypeInfo('tv', 'Television', Icons.tv),
  ApplianceTypeInfo('socket', 'Smart Socket', Icons.outlet),
  ApplianceTypeInfo('speaker', 'Speaker', Icons.speaker),
  ApplianceTypeInfo('router', 'Router', Icons.router),
  ApplianceTypeInfo('heater', 'Heater', Icons.thermostat),
];

class SwitchSettingsScreen extends ConsumerStatefulWidget {
  final DeviceModel device;
  final int switchIndex;

  const SwitchSettingsScreen({
    super.key,
    required this.device,
    required this.switchIndex,
  });

  @override
  ConsumerState<SwitchSettingsScreen> createState() => _SwitchSettingsScreenState();
}

class _SwitchSettingsScreenState extends ConsumerState<SwitchSettingsScreen> {
  late TextEditingController _nameController;
  late String _selectedIconId;
  bool _isLoading = false;
  
  SwitchConfigModel? get _switchConfig {
    try {
      return widget.device.switches.firstWhere((s) => s.switchIndex == widget.switchIndex);
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final sw = _switchConfig;
    _nameController = TextEditingController(text: sw?.name ?? 'Switch ${widget.switchIndex}');
    _selectedIconId = sw?.icon ?? 'lightbulb';
    
    // Ensure selected icon exists
    if (!applianceTypes.any((t) => t.id == _selectedIconId)) {
      _selectedIconId = 'lightbulb';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateSwitch() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(deviceRepositoryProvider).updateSwitch(
        widget.device.id,
        widget.switchIndex,
        name: _nameController.text.trim(),
        icon: _selectedIconId,
      );

      // Refresh devices to get updated switch names
      ref.read(dashboardControllerProvider.notifier).refreshDevices(widget.device.homeId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Switch updated successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Switch ${widget.switchIndex} Settings'),
        centerTitle: true,
        backgroundColor: bg,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'Edit Switch Details',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildTextFieldRow('Appliance Name', _nameController, isDark),
                        const Divider(height: 1),
                        _buildInfoRow('Device Name', widget.device.name, isDark),
                        const Divider(height: 1),
                        _buildDeviceIdRow('Device ID', widget.device.id, isDark),
                        const Divider(height: 1),
                        _buildInfoRow('Switch Number', '${widget.switchIndex}', isDark),
                        const Divider(height: 1),
                        _buildDropdownRow('Appliance Type', isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _updateSwitch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2979FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Update Switch',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceIdRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black)),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
                child: const Icon(Icons.copy, size: 20, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldRow(String label, TextEditingController controller, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.end,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter name',
              ),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _selectedIconId,
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
            dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            items: applianceTypes.map((type) {
              return DropdownMenuItem(
                value: type.id,
                child: Row(
                  children: [
                    Icon(type.icon, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(type.name, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedIconId = val);
              }
            },
          ),
        ],
      ),
    );
  }
}
