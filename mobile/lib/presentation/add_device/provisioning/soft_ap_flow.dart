import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/extensions.dart';

const Color _primary = Color(0xFF4C6FFF);
const Color _darkBg = Color(0xFF010817);
const Color _success = Color(0xFF00B894);

enum _ProvisionStep { instructions, scanning, connecting, naming, done, error }

class SoftApFlowScreen extends ConsumerStatefulWidget {
  const SoftApFlowScreen({super.key});

  @override
  ConsumerState<SoftApFlowScreen> createState() => _SoftApFlowScreenState();
}

class _SoftApFlowScreenState extends ConsumerState<SoftApFlowScreen> {
  _ProvisionStep _step = _ProvisionStep.instructions;
  String _deviceId = '';
  final _nameController = TextEditingController();
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    switch (_step) {
      case _ProvisionStep.instructions:
        setState(() => _step = _ProvisionStep.scanning);
        _simulateScan();
        break;
      case _ProvisionStep.scanning:
        break;
      case _ProvisionStep.connecting:
        break;
      case _ProvisionStep.naming:
        _completeProvisioning();
        break;
      case _ProvisionStep.done:
      case _ProvisionStep.error:
        break;
    }
  }

  Future<void> _simulateScan() async {
    // In production, use wifi_scan / network_info_plus to find NEURO_TOUCH_XXXXXX SSID
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _deviceId = 'nt-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _step = _ProvisionStep.connecting;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _step = _ProvisionStep.naming);
  }

  Future<void> _completeProvisioning() async {
    if (_nameController.text.trim().isEmpty) {
      context.showErrorSnackBar('Please enter a device name');
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _step = _ProvisionStep.done;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? _darkBg : Colors.white,
      appBar: AppBar(
        title: Text('SoftAP Setup',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? _darkBg : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStep(isDark),
      ),
    );
  }

  Widget _buildStep(bool isDark) {
    switch (_step) {
      case _ProvisionStep.instructions:
        return _InstructionsView(onNext: _nextStep, isDark: isDark);
      case _ProvisionStep.scanning:
        return _ScanningView(isDark: isDark);
      case _ProvisionStep.connecting:
        return _ConnectingView(deviceId: _deviceId, isDark: isDark);
      case _ProvisionStep.naming:
        return _NamingView(
          controller: _nameController,
          onComplete: _completeProvisioning,
          isLoading: _isLoading,
          isDark: isDark,
        );
      case _ProvisionStep.done:
        return _DoneView(
          deviceId: _deviceId,
          onFinish: () => context.go('/devices'),
          isDark: isDark,
        );
      case _ProvisionStep.error:
        return Center(child: Text(_error ?? 'Unknown error'));
    }
  }
}

class _InstructionsView extends StatelessWidget {
  final VoidCallback onNext;
  final bool isDark;

  const _InstructionsView({required this.onNext, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIcon(icon: Icons.wifi_tethering_rounded, color: _primary),
          const SizedBox(height: 24),
          Text(
            'Before you begin',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _InstructionStep(num: '1', text: 'Power on your Neuro Touch device'),
          _InstructionStep(num: '2', text: 'Wait for the LED to flash blue (hotspot mode)'),
          _InstructionStep(num: '3', text: 'Stay close to the device (within 2 meters)'),
          _InstructionStep(num: '4', text: 'Tap Next — the app will auto-connect'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Next',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String num;
  final String text;

  const _InstructionStep({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: _primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _ScanningView extends StatelessWidget {
  final bool isDark;
  const _ScanningView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _primary),
          const SizedBox(height: 24),
          Text('Scanning for Neuro Touch devices...',
              style: GoogleFonts.inter(fontSize: 15)),
        ],
      ),
    );
  }
}

class _ConnectingView extends StatelessWidget {
  final String deviceId;
  final bool isDark;

  const _ConnectingView({required this.deviceId, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _primary),
          const SizedBox(height: 24),
          Text('Found device: $deviceId',
              style: GoogleFonts.inter(fontSize: 14, color: _primary)),
          const SizedBox(height: 8),
          Text('Connecting and provisioning...',
              style: GoogleFonts.inter(fontSize: 15)),
        ],
      ),
    );
  }
}

class _NamingView extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onComplete;
  final bool isLoading;
  final bool isDark;

  const _NamingView({
    required this.controller,
    required this.onComplete,
    required this.isLoading,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIcon(icon: Icons.edit_rounded, color: _success),
          const SizedBox(height: 24),
          Text(
            'Name your device',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a meaningful name like "Living Room Switch"',
            style: GoogleFonts.inter(
              color: isDark ? const Color(0xFFB2BEC3) : const Color(0xFF555E68),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Device Name',
              prefixIcon: const Icon(Icons.devices_other_rounded),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onComplete,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text('Complete Setup',
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  final String deviceId;
  final VoidCallback onFinish;
  final bool isDark;

  const _DoneView({
    required this.deviceId,
    required this.onFinish,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _success.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: _success, size: 44),
          ),
          const SizedBox(height: 24),
          Text(
            'Device Added!',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Your device is now online and ready to control',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: isDark ? const Color(0xFFB2BEC3) : const Color(0xFF555E68),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onFinish,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Go to Devices',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _StepIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }
}
