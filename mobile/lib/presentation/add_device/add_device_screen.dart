import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/extensions.dart';

const Color _primary = Color(0xFF06457F);
const Color _darkBg = Color(0xFF33343B);

class AddDeviceScreen extends ConsumerWidget {
  const AddDeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: isDark ? _darkBg : const Color(0xFFEAFBFF),
      appBar: AppBar(
        title: Text('Add Device',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? _darkBg : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Choose Setup Method',
            style: GoogleFonts.inter(
              fontSize: screenSize.width * 0.048,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Follow the wizard to connect your Neuro Touch device',
            style: GoogleFonts.inter(
              color: isDark ? const Color(0xFFB2BEC3) : const Color(0xFF555E68),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          _SetupTile(
            icon: Icons.wifi_rounded,
            iconColor: _primary,
            title: 'SoftAP Provisioning',
            subtitle: 'Connect device via Wi-Fi hotspot (recommended)',
            onTap: () => context.push('/add-device/provisioning'),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _SetupTile(
            icon: Icons.qr_code_scanner_rounded,
            iconColor: const Color(0xFF6C5CE7),
            title: 'Scan QR Code',
            subtitle: 'Scan device QR code for instant setup',
            onTap: () => context.showInfoSnackBar('QR provisioning coming soon'),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _SetupTile(
            icon: Icons.search_rounded,
            iconColor: const Color(0xFF00B894),
            title: 'Auto Discover',
            subtitle: 'Scan network for nearby Neuro Touch devices',
            onTap: () => context.showInfoSnackBar('Network discovery coming soon'),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _SetupTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;

  const _SetupTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF45484D) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF55595E) : const Color(0xFFD1D5DB),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: isDark
                          ? const Color(0xFFB2BEC3)
                          : const Color(0xFF555E68),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? const Color(0xFFB2BEC3) : const Color(0xFF555E68),
            ),
          ],
        ),
      ),
    );
  }
}
