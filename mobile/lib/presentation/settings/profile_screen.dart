import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/auth.controller.dart';
import '../../core/utils/extensions.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          TextButton(onPressed: () {}, child: const Text('Edit')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: const Color(0xFF4C6FFF).withOpacity(0.15),
                  child: Text(
                    user?.name.initials ?? '?',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF4C6FFF),
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? 'Guest',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.contactDisplay ?? '',
                  style: GoogleFonts.inter(
                    color: isDark ? const Color(0xFFB2BEC3) : const Color(0xFF555E68),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Details
          _DetailRow(label: 'Name', value: user?.name ?? '-', isDark: isDark),
          _DetailRow(label: 'Email', value: user?.email ?? '-', isDark: isDark),
          _DetailRow(label: 'Phone', value: user?.phone ?? '-', isDark: isDark),
          _DetailRow(
            label: 'Joined',
            value: user?.createdAt.formatDate ?? '-',
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _DetailRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF45484D) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF55595E) : const Color(0xFFD1D5DB),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFFB2BEC3) : const Color(0xFF555E68),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
