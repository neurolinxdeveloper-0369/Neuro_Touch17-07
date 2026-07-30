import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../core/theme/app_typography.dart';
import '../common/widgets/glass_panel.dart';

class AlarmScreen extends StatefulWidget {
  final Map<String, String?> payload;

  const AlarmScreen({super.key, required this.payload});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Timer? _confirmationTimer;
  bool _showConfirmation = false;
  int _countdown = 5;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    
    // Start continuous alarm sound
    FlutterRingtonePlayer().playAlarm(looping: true, volume: 1.0);
  }

  @override
  void dispose() {
    FlutterRingtonePlayer().stop();
    _animationController.dispose();
    _confirmationTimer?.cancel();
    super.dispose();
  }

  void _onCloseTapped() {
    FlutterRingtonePlayer().stop(); // Pause sound to ask user
    setState(() {
      _showConfirmation = true;
      _countdown = 5;
    });

    // Start 5-second countdown
    _confirmationTimer?.cancel();
    _confirmationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          // Timer expired, user didn't confirm. Resume alarm!
          timer.cancel();
          _showConfirmation = false;
          _resumeAlarm();
        }
      });
    });
  }

  void _resumeAlarm() {
    // Timer expired without confirmation. Resume the alarm sound!
    FlutterRingtonePlayer().playAlarm(looping: true, volume: 1.0);
  }

  void _onConfirmTapped() {
    // User successfully confirmed the dismissal
    _confirmationTimer?.cancel();
    FlutterRingtonePlayer().stop();
    AwesomeNotifications().dismiss(widget.payload['device_id'].hashCode);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final deviceId = widget.payload['device_id'] ?? 'Unknown ID';
    final roomName = widget.payload['room_name'] ?? 'Unknown Room';
    final temperature = widget.payload['temperature'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.redAccent.withValues(alpha: 0.8 + (_animationController.value * 0.2)),
                  Colors.black,
                ],
                radius: 1.5 + (_animationController.value * 0.2),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.white, size: 100),
                    const SizedBox(height: 24),
                    Text(
                      'CRITICAL ALARM',
                      style: AppTypography.h1.copyWith(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TEMPERATURE EXCEEDED',
                      style: AppTypography.titleMedium.copyWith(color: Colors.white70, letterSpacing: 2),
                    ),
                    const SizedBox(height: 48),
                    GlassPanel(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildInfoRow('Room', roomName),
                          const Divider(color: Colors.white24, height: 32),
                          _buildInfoRow('Device ID', deviceId),
                          const Divider(color: Colors.white24, height: 32),
                          _buildInfoRow('Live Temp', '$temperature°C', isAlert: true),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (!_showConfirmation)
                      SizedBox(
                        width: double.infinity,
                        height: 70,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                          ),
                          onPressed: _onCloseTapped,
                          child: const Text('CLOSE ALARM', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Text('Are you sure?', style: AppTypography.h3.copyWith(color: Colors.white)),
                          const SizedBox(height: 8),
                          Text('Alarm will resume in $_countdown seconds', style: AppTypography.bodyMedium.copyWith(color: Colors.white70)),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: _onConfirmTapped,
                              child: const Text('CONFIRM CLOSE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isAlert = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyLarge.copyWith(color: Colors.white70)),
        Text(
          value,
          style: AppTypography.h3.copyWith(
            color: isAlert ? Colors.yellow : Colors.white,
            fontWeight: isAlert ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
