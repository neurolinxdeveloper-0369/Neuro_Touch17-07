import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/extensions.dart';

const Color _primary = Color(0xFF4C6FFF);
const Color _darkBg = Color(0xFF010817);
const Color _darkTextPrimary = Color(0xFFFFFFFF);
const Color _darkTextSecondary = Color(0xFFB2BEC3);
const Color _lightTextPrimary = Color(0xFF0F172A);
const Color _lightTextSecondary = Color(0xFF555E68);

class AutomationScreen extends ConsumerStatefulWidget {
  const AutomationScreen({super.key});

  @override
  ConsumerState<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends ConsumerState<AutomationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bgColor = isDark ? _darkBg : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Automation',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => context.push('/automation/chat'),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: _primary,
          unselectedLabelColor:
              isDark ? _darkTextSecondary : _lightTextSecondary,
          indicatorColor: _primary,
          indicatorWeight: 3,
          labelStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400),
          tabs: const [
            Tab(text: 'Scenes'),
            Tab(text: 'Schedules'),
            Tab(text: 'Alerts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ScenesTab(isDark: isDark),
          _SchedulesTab(isDark: isDark),
          _AlertsTab(isDark: isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/automation/scene/new'),
        backgroundColor: _primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

class _ScenesTab extends StatelessWidget {
  final bool isDark;
  const _ScenesTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 48,
              color: isDark ? _darkTextSecondary : _lightTextSecondary),
          const SizedBox(height: 12),
          Text(
            'No automations yet',
            style: GoogleFonts.inter(
              color: isDark ? _darkTextPrimary : _lightTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to create your first scene',
            style: GoogleFonts.inter(
              color: isDark ? _darkTextSecondary : _lightTextSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SchedulesTab extends StatelessWidget {
  final bool isDark;
  const _SchedulesTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded,
              size: 48,
              color: isDark ? _darkTextSecondary : _lightTextSecondary),
          const SizedBox(height: 12),
          Text(
            'No schedules yet',
            style: GoogleFonts.inter(
              color: isDark ? _darkTextPrimary : _lightTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Schedule devices to turn on/off at specific times',
            style: GoogleFonts.inter(
              color: isDark ? _darkTextSecondary : _lightTextSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AlertsTab extends StatelessWidget {
  final bool isDark;
  const _AlertsTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_outlined,
              size: 48,
              color: isDark ? _darkTextSecondary : _lightTextSecondary),
          const SizedBox(height: 12),
          Text(
            'No alerts',
            style: GoogleFonts.inter(
              color: isDark ? _darkTextPrimary : _lightTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
