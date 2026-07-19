import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/auth.controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../common/widgets/app_screen_wrapper.dart';
import '../common/widgets/glass_panel.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final user = ref.watch(currentUserProvider);

    return AppScreenWrapper(
      title: 'Profile',
      actions: [
        TextButton(onPressed: () {}, child: const Text('Edit')),
      ],
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: user?.profilePictureUrl != null ? NetworkImage(user!.profilePictureUrl!) : null,
                    child: user?.profilePictureUrl == null
                        ? Text(
                            user?.name.initials ?? '?',
                            style: AppTypography.h1.copyWith(color: AppColors.primary, fontSize: 40),
                          )
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Text(user?.name ?? 'Neuro Touch User', style: AppTypography.h2),
                  Text(user?.contactDisplay ?? '', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(isDark))),
                ],
              ),
            ),
            const SizedBox(height: 48),
            GlassPanel(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _DetailRow(label: 'Full Name', value: user?.name ?? '-'),
                  _DetailRow(label: 'Email Address', value: user?.email ?? '-'),
                  _DetailRow(label: 'Phone Number', value: user?.phone ?? '-'),
                  _DetailRow(label: 'Member Since', value: user?.createdAt.formatDate ?? '-', isLast: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: AppColors.borderColor(isDark), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(isDark))),
          Text(value, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
