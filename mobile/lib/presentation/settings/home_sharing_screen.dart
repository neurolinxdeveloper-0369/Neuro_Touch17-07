import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/extensions.dart';

class HomeSharingScreen extends ConsumerWidget {
  const HomeSharingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Home Sharing',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Invite'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline_rounded,
                  size: 52, color: Color(0xFF4C6FFF)),
              const SizedBox(height: 16),
              Text(
                'Share your home',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Invite family members to control devices together.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: isDark ? const Color(0xFFB2BEC3) : const Color(0xFF555E68),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.share_rounded),
                label: const Text('Generate Invite Code'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
