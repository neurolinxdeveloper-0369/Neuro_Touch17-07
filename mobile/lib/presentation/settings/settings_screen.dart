import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/auth.controller.dart';
import '../../app.dart';
import '../../core/utils/extensions.dart';
import '../../data/services/storage_service.dart';

const Color _primary = Color(0xFF4C6FFF);
const Color _darkBg = Color(0xFF010817);
const Color _cardDark = Color(0xFF45484D);
const Color _darkTextPrimary = Color(0xFFFFFFFF);
const Color _darkTextSecondary = Color(0xFFB2BEC3);
const Color _lightTextPrimary = Color(0xFF0F172A);
const Color _lightTextSecondary = Color(0xFF555E68);
const Color _borderDark = Color(0xFF55595E);
const Color _borderLight = Color(0xFFD1D5DB);
const Color _error = Color(0xFFE17055);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final bgColor = isDark ? _darkBg : const Color(0xFFF2F3F5);
    final appBarColor = isDark ? _darkBg : const Color(0xFF194B85);
    final textPrimary = isDark ? _darkTextPrimary : _lightTextPrimary;
    final textSecondary = isDark ? _darkTextSecondary : _lightTextSecondary;


    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: appBarColor,
            elevation: 0,
            title: Text('Settings',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User profile card
                  GestureDetector(
                    onTap: () => context.push('/settings/profile'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4C6FFF), Color(0xFF6C5CE7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            backgroundImage: (user?.profilePictureUrl != null && user!.profilePictureUrl!.isNotEmpty)
                                ? NetworkImage(user.profilePictureUrl!)
                                : null,
                            child: (user?.profilePictureUrl == null || user!.profilePictureUrl!.isEmpty)
                                ? Text(
                                    user?.name.initials ?? '?',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ?? 'Guest',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user?.contactDisplay ?? '',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.white),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Home Management
                  _SettingsSection(
                    title: 'Home Management',
                    isDark: isDark,
                    children: [
                      _SettingsTile(
                        icon: Icons.layers_outlined,
                        label: 'Floors & Rooms',
                        isDark: isDark,
                        onTap: () => context.push('/settings/floors-rooms'),
                      ),
                      _SettingsTile(
                        icon: Icons.people_outline_rounded,
                        label: 'Home Sharing',
                        isDark: isDark,
                        onTap: () => context.push('/settings/home-sharing'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Appearance
                  _SettingsSection(
                    title: 'Appearance',
                    isDark: isDark,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.palette_outlined,
                                  color: _primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Theme',
                                style: GoogleFonts.inter(
                                  color: textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            DropdownButton<ThemeMode>(
                              value: themeMode,
                              underline: const SizedBox.shrink(),
                              style: GoogleFonts.inter(
                                  color: isDark ? _darkTextPrimary : Colors.white, fontSize: 14),
                              dropdownColor: isDark ? _cardDark : const Color(0xFF194B85),
                              items: const [
                                DropdownMenuItem(
                                  value: ThemeMode.system,
                                  child: Text('System'),
                                ),
                                DropdownMenuItem(
                                  value: ThemeMode.light,
                                  child: Text('Light'),
                                ),
                                DropdownMenuItem(
                                  value: ThemeMode.dark,
                                  child: Text('Dark'),
                                ),
                              ],
                              onChanged: (mode) {
                                if (mode == null) return;
                                ref.read(themeModeProvider.notifier).state =
                                    mode;
                                ref
                                    .read(storageServiceProvider)
                                    .saveThemeMode(mode);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Support
                  _SettingsSection(
                    title: 'Support',
                    isDark: isDark,
                    children: [
                      _SettingsTile(
                        icon: Icons.description_outlined,
                        label: 'Privacy Policy',
                        isDark: isDark,
                        onTap: () => context.push('/settings/webview', extra: {
                          'url': 'https://neurotouch.in/privacy',
                          'title': 'Privacy Policy',
                        }),
                      ),
                      _SettingsTile(
                        icon: Icons.article_outlined,
                        label: 'Terms of Service',
                        isDark: isDark,
                        onTap: () => context.push('/settings/webview', extra: {
                          'url': 'https://neurotouch.in/terms',
                          'title': 'Terms of Service',
                        }),
                      ),
                      _SettingsTile(
                        icon: Icons.info_outline_rounded,
                        label: 'About Neuro Touch',
                        isDark: isDark,
                        onTap: () {},
                        trailing: Text(
                          'v1.0.0',
                          style: GoogleFonts.inter(
                              color: textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Sign out
                  _SettingsSection(
                    title: '',
                    isDark: isDark,
                    children: [
                      _SettingsTile(
                        icon: Icons.logout_rounded,
                        label: 'Sign Out',
                        labelColor: _error,
                        isDark: isDark,
                        onTap: () => _showLogoutDialog(context, ref),
                      ),
                    ],
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(authControllerProvider.notifier).logout();
              });
            },
            child: const Text('Sign Out',
                style: TextStyle(color: _error)),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDark;

  const _SettingsSection({
    required this.title,
    required this.children,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? _darkTextSecondary : _lightTextSecondary;
    final cardColor = isDark ? _cardDark : const Color(0xFF194B85);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.inter(
                color: textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? _borderDark : _borderLight,
              width: 0.5,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final bool isDark;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.labelColor,
    required this.isDark,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? _darkTextPrimary : Colors.white;
    final textSecondary = isDark ? _darkTextSecondary : Colors.white70;
    final finalIconColor = isDark ? _primary : Colors.white;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: finalIconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: finalIconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: labelColor ?? textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    color: textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}
