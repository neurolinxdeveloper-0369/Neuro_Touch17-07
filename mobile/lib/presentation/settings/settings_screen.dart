import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/auth.controller.dart';
import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../data/services/storage_service.dart';
import '../common/widgets/app_screen_wrapper.dart';
import '../common/widgets/glass_panel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);

    return AppScreenWrapper(
      title: 'Settings',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            _ProfileSummaryCard(user: user),
            const SizedBox(height: 32),
            _SettingsSection(
              title: 'Home',
              children: [
                _SettingsTile(icon: Icons.people_outline_rounded, label: 'Home Sharing', onTap: () => context.push('/settings/home-sharing')),
              ],
            ),
            const SizedBox(height: 24),
            _SettingsSection(
              title: 'Appearance',
              children: [
                _ThemeSelector(
                  currentMode: themeMode,
                  onChanged: (mode) {
                    ref.read(themeModeProvider.notifier).state = mode;
                    ref.read(storageServiceProvider).saveThemeMode(mode);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SettingsSection(
              title: 'Support',
              children: [
                _SettingsTile(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', onTap: () => context.push('/legal?type=privacy')),
                _SettingsTile(icon: Icons.description_outlined, label: 'Terms of Use', onTap: () => context.push('/legal?type=terms')),
                _SettingsTile(icon: Icons.info_outline_rounded, label: 'About', onTap: () {}, trailing: const Text('v1.1.0')),
              ],
            ),
            const SizedBox(height: 24),
            _SettingsSection(
              title: '',
              children: [
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  color: AppColors.error,
                  onTap: () => _showLogoutDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out from Neuro Touch?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // 1. Close the dialog first
              Navigator.of(dialogContext).pop();
              // 2. Schedule logout to avoid collision with Navigator animations
              Future.delayed(const Duration(milliseconds: 100), () {
                ref.read(authControllerProvider.notifier).logout();
              });
            },
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  final dynamic user;
  const _ProfileSummaryCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return GestureDetector(
      onTap: () => context.push('/settings/profile'),
      child: GlassPanel(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: user?.profilePictureUrl != null ? NetworkImage(user.profilePictureUrl) : null,
              child: user?.profilePictureUrl == null ? Text(user?.name.initials ?? '?', style: AppTypography.h3.copyWith(color: AppColors.primary)) : null,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.name ?? 'Guest User', style: AppTypography.h3),
                  Text(user?.contactDisplay ?? 'No contact info', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(isDark))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary(isDark)),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title.toUpperCase(), style: AppTypography.label.copyWith(color: AppColors.textSecondary(isDark))),
          ),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Widget? trailing;

  const _SettingsTile({required this.icon, required this.label, required this.onTap, this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? AppColors.primary, size: 24),
      title: Text(label, style: AppTypography.bodyLarge.copyWith(color: color ?? AppColors.textPrimary(isDark), fontWeight: FontWeight.w500)),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary(isDark), size: 20),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSelector({required this.currentMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.palette_outlined, color: AppColors.primary),
      title: Text('Theme', style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w500)),
      trailing: DropdownButton<ThemeMode>(
        value: currentMode,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
        ],
        onChanged: (v) => v != null ? onChanged(v) : null,
      ),
    );
  }
}
