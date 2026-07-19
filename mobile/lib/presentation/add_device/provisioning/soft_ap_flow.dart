import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../controllers/provision.controller.dart';
import '../../../controllers/dashboard.controller.dart';
import '../../../controllers/home_setup.controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/floor.model.dart';
import '../../../data/models/room.model.dart';

// ─── Theme constants ───────────────────────────────────────────────────────
const Color _primary = Color(0xFF2979FF);
const Color _surface = Color(0xFF12131A);
const Color _cardBg = Color(0xFF1A1B26);
const Color _border = Color(0xFF2A2B3D);
const Color _success = Color(0xFF00E676);

// ─── Root Screen ──────────────────────────────────────────────────────────

class SoftApFlowScreen extends ConsumerStatefulWidget {
  final int panelNumber;

  const SoftApFlowScreen({super.key, required this.panelNumber});

  @override
  ConsumerState<SoftApFlowScreen> createState() => _SoftApFlowScreenState();
}

class _SoftApFlowScreenState extends ConsumerState<SoftApFlowScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      String homeId = ref.read(homeIdProvider) ?? '';
      
      // Fallback: If no home selected in storage, grab the first available home
      if (homeId.isEmpty) {
        try {
          final homes = await ref.read(userHomesProvider.future);
          if (homes.isNotEmpty) {
            homeId = homes.first.id;
          }
        } catch (_) {}
      }

      await ref
          .read(provisionControllerProvider.notifier)
          .initPanel(widget.panelNumber, homeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(provisionControllerProvider);
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? _surface : const Color(0xFFF0F2FF),
      appBar: _buildAppBar(context, state),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        ),
        child: _buildStep(state, isDark),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, ProvisionState state) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () {
          ref.read(provisionControllerProvider.notifier).reset();
          context.pop();
        },
      ),
      title: Text(
        _titleForStep(state.step, state.panelNumber),
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
      centerTitle: true,
      bottom: _buildProgressBar(state.step),
    );
  }

  String _titleForStep(ProvisionStep step, int panel) {
    switch (step) {
      case ProvisionStep.panelSelected:
      case ProvisionStep.instructions:
        return 'Touch Panel $panel Setup';
      case ProvisionStep.awaitingHotspotConnection:
        return 'Connect to Device';
      case ProvisionStep.networkChoice:
        return 'Select Network';
      case ProvisionStep.customNetwork:
        return 'Enter Network Details';
      case ProvisionStep.sendingCredentials:
        return 'Configuring Device';
      case ProvisionStep.waitingForDevice:
        return 'Waiting for Device';
      case ProvisionStep.naming:
        return 'Name Your Device';
      case ProvisionStep.assigning:
        return 'Assign Location';
      case ProvisionStep.success:
        return 'Setup Complete!';
      case ProvisionStep.error:
        return 'Setup Failed';
    }
  }

  PreferredSizeWidget? _buildProgressBar(ProvisionStep step) {
    const steps = [
      ProvisionStep.instructions,
      ProvisionStep.awaitingHotspotConnection,
      ProvisionStep.networkChoice,
      ProvisionStep.sendingCredentials,
      ProvisionStep.waitingForDevice,
      ProvisionStep.naming,
      ProvisionStep.assigning,
      ProvisionStep.success,
    ];
    final idx = steps.indexOf(step);
    if (idx < 0) return null;
    final progress = (idx + 1) / steps.length;
    return PreferredSize(
      preferredSize: const Size.fromHeight(3),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: _border,
        color: _primary,
        minHeight: 3,
      ),
    );
  }

  Widget _buildStep(ProvisionState state, bool isDark) {
    switch (state.step) {
      case ProvisionStep.panelSelected:
      case ProvisionStep.instructions:
        return _InstructionsStep(
            key: const ValueKey('instructions'), isDark: isDark);
      case ProvisionStep.awaitingHotspotConnection:
        return _AwaitingHotspotStep(
            key: const ValueKey('hotspot'), isDark: isDark);
      case ProvisionStep.networkChoice:
        return _NetworkChoiceStep(
            key: const ValueKey('network-choice'), isDark: isDark);
      case ProvisionStep.customNetwork:
        return _CustomNetworkStep(
            key: const ValueKey('custom-network'), isDark: isDark);
      case ProvisionStep.sendingCredentials:
        return _SendingCredentialsStep(
            key: const ValueKey('sending'), isDark: isDark);
      case ProvisionStep.waitingForDevice:
        return _WaitingForDeviceStep(
            key: const ValueKey('waiting'), isDark: isDark);
      case ProvisionStep.naming:
        return _NamingStep(key: const ValueKey('naming'), isDark: isDark);
      case ProvisionStep.assigning:
        return _AssignmentStep(
            key: const ValueKey('assigning'), isDark: isDark);
      case ProvisionStep.success:
        return _SuccessStep(key: const ValueKey('success'), isDark: isDark);
      case ProvisionStep.error:
        return _ErrorStep(key: const ValueKey('error'), isDark: isDark);
    }
  }
}

// ─── Step 1: Instructions ────────────────────────────────────────────────

class _InstructionsStep extends ConsumerWidget {
  final bool isDark;
  const _InstructionsStep({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisionControllerProvider);
    return _StepScaffold(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GlowIcon(
            icon: Icons.wifi_tethering_rounded,
            color: _primary,
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          Text(
            'Before You Begin',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Setting up Touch Panel ${state.panelNumber}',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          _InstructionItem(
            num: '1',
            icon: Icons.power_settings_new_rounded,
            title: 'Power on your Touch Panel ${state.panelNumber}',
            subtitle: 'Wait for the LED to flash — device is in hotspot mode',
          ),
          _InstructionItem(
            num: '2',
            icon: Icons.signal_cellular_off_rounded,
            title: 'Turn OFF mobile data',
            subtitle:
                'Go to Settings → Turn off Mobile Data / Cellular Data before proceeding',
            highlight: true,
          ),
          _InstructionItem(
            num: '3',
            icon: Icons.wifi_rounded,
            title: 'Connect to the device hotspot',
            subtitle:
                'Look for Wi-Fi network: ${state.expectedSsid}',
          ),
          _InstructionItem(
            num: '4',
            icon: Icons.check_circle_rounded,
            title: 'Return to this app',
            subtitle:
                'Once connected to the hotspot, come back here and tap Next',
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'I\'ve Connected to the Hotspot',
            onTap: () => ref
                .read(provisionControllerProvider.notifier)
                .confirmInstructions(),
          ),
        ],
      ),
    );
  }
}

// ─── Step 2: Awaiting Hotspot Connection ─────────────────────────────────

class _AwaitingHotspotStep extends ConsumerWidget {
  final bool isDark;
  const _AwaitingHotspotStep({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisionControllerProvider);
    return _StepScaffold(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          _GlowIcon(
            icon: Icons.phone_android_rounded,
            color: _primary,
            isDark: isDark,
          ),
          const SizedBox(height: 28),
          Text(
            'Connect Your Phone to\nDevice Hotspot',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.wifi_rounded, color: _primary, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Expected Wi-Fi Network:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  state.expectedSsid,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _InfoCard(
            isDark: isDark,
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orangeAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mobile data must be OFF for this to work',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'I\'m Connected to ${state.expectedSsid}',
            onTap: () => ref
                .read(provisionControllerProvider.notifier)
                .confirmHotspotConnected(),
          ),
        ],
      ),
    );
  }
}

// ─── Step 3: Network Choice ───────────────────────────────────────────────

class _NetworkChoiceStep extends ConsumerWidget {
  final bool isDark;
  const _NetworkChoiceStep({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisionControllerProvider);
    return _StepScaffold(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GlowIcon(
            icon: Icons.router_rounded,
            color: _primary,
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          Text(
            'Which network should the\ndevice connect to?',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the Wi-Fi network your Touch Panel will use at home',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          // Home network option
          _NetworkOption(
            isDark: isDark,
            icon: Icons.home_rounded,
            title: 'Home Network',
            subtitle: (state.homeSsid != null && state.homeSsid!.isNotEmpty)
                ? state.homeSsid!
                : 'Not configured (Tap to enter manually)',
            badge: (state.homeSsid != null && state.homeSsid!.isNotEmpty)
                ? 'Recommended'
                : null,
            onTap: () {
              if (state.homeSsid != null && state.homeSsid!.isNotEmpty) {
                ref.read(provisionControllerProvider.notifier).selectHomeNetwork();
              } else {
                ref.read(provisionControllerProvider.notifier).selectCustomNetwork();
              }
            },
          ),
          const SizedBox(height: 16),
          _NetworkOption(
            isDark: isDark,
            icon: Icons.add_circle_outline_rounded,
            title: 'Another Network',
            subtitle: 'Enter SSID and password manually',
            onTap: () => ref
                .read(provisionControllerProvider.notifier)
                .selectCustomNetwork(),
          ),
        ],
      ),
    );
  }
}

// ─── Step 4: Custom Network Entry ─────────────────────────────────────────

class _CustomNetworkStep extends ConsumerStatefulWidget {
  final bool isDark;
  const _CustomNetworkStep({super.key, required this.isDark});

  @override
  ConsumerState<_CustomNetworkStep> createState() => _CustomNetworkStepState();
}

class _CustomNetworkStepState extends ConsumerState<_CustomNetworkStep> {
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GlowIcon(
            icon: Icons.wifi_password_rounded,
            color: _primary,
            isDark: widget.isDark,
          ),
          const SizedBox(height: 24),
          Text(
            'Enter Network Details',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The device will connect to this Wi-Fi network',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          _FormField(
            controller: _ssidCtrl,
            label: 'Wi-Fi Network Name (SSID)',
            icon: Icons.wifi_rounded,
            isDark: widget.isDark,
          ),
          const SizedBox(height: 16),
          _FormField(
            controller: _passCtrl,
            label: 'Wi-Fi Password',
            icon: Icons.lock_rounded,
            isDark: widget.isDark,
            obscureText: !_showPass,
            suffixIcon: IconButton(
              icon: Icon(
                  _showPass ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'Connect Device to This Network',
            onTap: () {
              if (_ssidCtrl.text.trim().isEmpty) {
                context.showErrorSnackBar('Please enter the Wi-Fi network name');
                return;
              }
              ref
                  .read(provisionControllerProvider.notifier)
                  .submitCustomNetwork(
                    _ssidCtrl.text.trim(),
                    _passCtrl.text,
                  );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Step 5: Sending Credentials ────────────────────────────────────────

class _SendingCredentialsStep extends StatelessWidget {
  final bool isDark;
  const _SendingCredentialsStep({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: _primary,
                    strokeWidth: 2.5,
                  ),
                  const Icon(Icons.wifi_rounded, color: _primary, size: 28),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Sending Wi-Fi credentials\nto your device…',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Communicating with device at 192.168.0.4',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 6: Waiting for Device ──────────────────────────────────────────

class _WaitingForDeviceStep extends ConsumerStatefulWidget {
  final bool isDark;
  const _WaitingForDeviceStep({super.key, required this.isDark});

  @override
  ConsumerState<_WaitingForDeviceStep> createState() =>
      _WaitingForDeviceStepState();
}

class _WaitingForDeviceStepState
    extends ConsumerState<_WaitingForDeviceStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  int _dots = 0;
  late Timer _dotTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _dotTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _dots = (_dots + 1) % 4);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _dotTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(provisionControllerProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primary.withOpacity(0.08 + _pulseCtrl.value * 0.08),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withOpacity(0.3 + _pulseCtrl.value * 0.2),
                        blurRadius: 20 + _pulseCtrl.value * 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.devices_rounded,
                      color: _primary, size: 36),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Waiting for device${'.' * _dots}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The device is connecting to your Wi-Fi network.\nThis may take up to 60 seconds.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey,
                height: 1.5,
              ),
            ),
            if (state.tempDeviceId.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _primary.withOpacity(0.3)),
                ),
                child: Text(
                  'Device ID: ${state.tempDeviceId}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Step 7: Naming ──────────────────────────────────────────────────────

class _NamingStep extends ConsumerStatefulWidget {
  final bool isDark;
  const _NamingStep({super.key, required this.isDark});

  @override
  ConsumerState<_NamingStep> createState() => _NamingStepState();
}

class _NamingStepState extends ConsumerState<_NamingStep> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(provisionControllerProvider);
    _ctrl.text = state.deviceName.isNotEmpty
        ? state.deviceName
        : 'Touch Panel ${state.panelNumber}';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(provisionControllerProvider);
    return _StepScaffold(
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GlowIcon(
            icon: Icons.edit_rounded,
            color: _success,
            isDark: widget.isDark,
          ),
          const SizedBox(height: 24),
          Text(
            'Device Connected! 🎉',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Give your Touch Panel ${state.panelNumber} a meaningful name',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
          ),
          if (state.macAddress.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoCard(
              isDark: widget.isDark,
              child: Row(
                children: [
                  const Icon(Icons.fingerprint_rounded,
                      color: _success, size: 18),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MAC Address',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.grey)),
                      Text(
                        state.macAddress,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          _FormField(
            controller: _ctrl,
            label: 'Device Name',
            icon: Icons.devices_other_rounded,
            isDark: widget.isDark,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              'Living Room Panel',
              'Bedroom Panel',
              'Kitchen Panel',
              'Office Panel',
            ].map((s) {
              return ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 12)),
                onPressed: () => _ctrl.text = s,
                backgroundColor: _primary.withOpacity(0.1),
                labelStyle: const TextStyle(color: _primary),
              );
            }).toList(),
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'Continue',
            isLoading: state.isLoading,
            onTap: () {
              if (_ctrl.text.trim().isEmpty) {
                context.showErrorSnackBar('Please enter a name for your device');
                return;
              }
              ref
                  .read(provisionControllerProvider.notifier)
                  .submitName(_ctrl.text.trim());
            },
          ),
        ],
      ),
    );
  }
}

// ─── Step 8: Assignment ──────────────────────────────────────────────────

class _AssignmentStep extends ConsumerWidget {
  final bool isDark;
  const _AssignmentStep({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisionControllerProvider);
    final homeId = ref.read(homeIdProvider) ?? '';
    // If we couldn't get a homeId from provider, we might still be loading, 
    // but the controller handles the assignment.

    return _StepScaffold(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GlowIcon(
            icon: Icons.location_on_rounded,
            color: _primary,
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          Text(
            'Assign to a Location',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Where is "${state.deviceName}" installed?',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 28),

          // Assignment type picker
          Row(
            children: [
              _AssignTypeChip(
                  label: 'Room',
                  icon: Icons.meeting_room_rounded,
                  selected: state.assignmentType == 'room',
                  onTap: () => ref
                      .read(provisionControllerProvider.notifier)
                      .setAssignmentType('room')),
              const SizedBox(width: 10),
              _AssignTypeChip(
                  label: 'Floor',
                  icon: Icons.stairs_rounded,
                  selected: state.assignmentType == 'floor',
                  onTap: () => ref
                      .read(provisionControllerProvider.notifier)
                      .setAssignmentType('floor')),
              const SizedBox(width: 10),
              _AssignTypeChip(
                  label: 'Site',
                  icon: Icons.location_city_rounded,
                  selected: state.assignmentType == 'site',
                  onTap: () => ref
                      .read(provisionControllerProvider.notifier)
                      .setAssignmentType('site')),
              const SizedBox(width: 10),
              _AssignTypeChip(
                  label: 'Outdoor',
                  icon: Icons.park_rounded,
                  selected: state.assignmentType == 'outdoor',
                  onTap: () => ref
                      .read(provisionControllerProvider.notifier)
                      .setAssignmentType('outdoor')),
            ],
          ),
          const SizedBox(height: 24),

          // Floor dropdown (if floors exist)
          if ((state.assignmentType == 'floor' ||
                  state.assignmentType == 'room') &&
              state.floors.isNotEmpty) ...[
            Text('Select Floor',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _DropdownField<FloorModel>(
              isDark: isDark,
              hint: 'Choose a floor',
              value: state.floors.firstWhereOrNull(
                  (f) => f.id == state.selectedFloorId),
              items: state.floors,
              labelBuilder: (f) => f.name,
              onChanged: (f) {
                if (f != null) {
                  ref
                      .read(provisionControllerProvider.notifier)
                      .setSelectedFloor(f.id);
                }
              },
            ),
            const SizedBox(height: 16),
          ],

          // Room dropdown (if rooms loaded)
          if (state.assignmentType == 'room' && state.rooms.isNotEmpty) ...[
            Text('Select Room',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _DropdownField<RoomModel>(
              isDark: isDark,
              hint: 'Choose a room',
              value:
                  state.rooms.firstWhereOrNull((r) => r.id == state.selectedRoomId),
              items: state.rooms,
              labelBuilder: (r) => r.name,
              onChanged: (r) {
                if (r != null) {
                  ref
                      .read(provisionControllerProvider.notifier)
                      .setSelectedRoom(r.id);
                }
              },
            ),
            const SizedBox(height: 16),
          ],

          if (state.assignmentType == 'site' ||
              state.assignmentType == 'outdoor') ...[
            _InfoCard(
              isDark: isDark,
              child: Row(
                children: [
                  Icon(
                    state.assignmentType == 'outdoor'
                        ? Icons.park_rounded
                        : Icons.location_city_rounded,
                    color: _primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Assignment is optional for ${state.assignmentType} devices',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),
          _PrimaryButton(
            label: 'Save Device',
            isLoading: state.isLoading,
            onTap: () => ref
                .read(provisionControllerProvider.notifier)
                .completeProvisioning(homeId),
          ),
          const SizedBox(height: 12),
          if (state.assignmentType != 'room')
            Center(
              child: TextButton(
                onPressed: () => ref
                    .read(provisionControllerProvider.notifier)
                    .completeProvisioning(homeId),
                child: Text(
                  'Skip — assign later',
                  style:
                      GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Step 9: Success ──────────────────────────────────────────────────────

class _SuccessStep extends ConsumerWidget {
  final bool isDark;
  const _SuccessStep({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisionControllerProvider);
    final device = state.provisionedDevice;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _success.withOpacity(0.12),
                boxShadow: [
                  BoxShadow(
                    color: _success.withOpacity(0.4),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded,
                  color: _success, size: 52),
            ),
            const SizedBox(height: 32),
            Text(
              'Device Added!',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (device != null) ...[
              Text(
                device.name,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${device.switchCount} switches ready to control',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              if (state.macAddress.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'MAC: ${state.macAddress}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 40),
            _PrimaryButton(
              label: 'Go to Devices',
              onTap: () {
                ref.read(provisionControllerProvider.notifier).reset();
                context.go('/devices');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error Step ──────────────────────────────────────────────────────────

class _ErrorStep extends ConsumerWidget {
  final bool isDark;
  const _ErrorStep({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisionControllerProvider);
    return _StepScaffold(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(0.12),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child:
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 44),
          ),
          const SizedBox(height: 28),
          Text(
            'Setup Failed',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            isDark: isDark,
            child: Text(
              state.errorMessage ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.inter(fontSize: 14, color: Colors.red.shade300),
            ),
          ),
          const SizedBox(height: 32),
          _InfoCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Try these steps:',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                _BulletPoint('Confirm mobile data is turned OFF'),
                _BulletPoint('Check you\'re connected to ${state.expectedSsid}'),
                _BulletPoint('Make sure the device LED is flashing'),
                _BulletPoint('Move closer to the device'),
              ],
            ),
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'Try Again',
            onTap: () =>
                ref.read(provisionControllerProvider.notifier).retry(),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              ref.read(provisionControllerProvider.notifier).reset();
              context.pop();
            },
            child: Text(
              'Cancel Setup',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────

class _StepScaffold extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _StepScaffold({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 140,
        ),
        child: IntrinsicHeight(child: child),
      ),
    );
  }
}

class _GlowIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;

  const _GlowIcon(
      {required this.icon, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 34),
    );
  }
}

class _InstructionItem extends StatelessWidget {
  final String num;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlight;

  const _InstructionItem({
    required this.num,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlight
                  ? Colors.orangeAccent.withOpacity(0.15)
                  : _primary.withOpacity(0.12),
              border: Border.all(
                color: highlight ? Colors.orangeAccent : _primary,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                num,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: highlight ? Colors.orangeAccent : _primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon,
                        size: 16,
                        color:
                            highlight ? Colors.orangeAccent : _primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: highlight ? Colors.orangeAccent : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkOption extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _NetworkOption({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? _cardBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(badge!,
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: _success,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _InfoCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _cardBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isDark;
  final bool obscureText;
  final Widget? suffixIcon;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.isDark,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: GoogleFonts.inter(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? _cardBg : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
      ),
    );
  }
}

class _AssignTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AssignTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _primary.withOpacity(0.15) : _cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _primary : _border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? _primary : Colors.grey, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? _primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final bool isDark;
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.isDark,
    required this.hint,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? _cardBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: isDark ? _cardBg : Colors.white,
        items: items
            .map((item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(labelBuilder(item),
                      style: GoogleFonts.inter(fontSize: 14)),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const _PrimaryButton({
    required this.label,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primary.withOpacity(0.4),
          elevation: 0,
          shadowColor: _primary.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                label,
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

// Utility extension on Iterable
extension _IterableExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
