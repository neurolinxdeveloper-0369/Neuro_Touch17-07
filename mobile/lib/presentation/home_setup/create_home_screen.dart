import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/home_setup.controller.dart';
import '../../controllers/dashboard.controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';

class CreateHomeScreen extends ConsumerStatefulWidget {
  const CreateHomeScreen({super.key});

  @override
  ConsumerState<CreateHomeScreen> createState() => _CreateHomeScreenState();
}

class _CreateHomeScreenState extends ConsumerState<CreateHomeScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedType = 'flat';
  int _floorCount = 2;
  bool _showPassword = false;

  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _homeTypes = [
    _HomeTypeOption(value: 'flat', label: 'Flat', icon: Icons.apartment_rounded),
    _HomeTypeOption(value: 'villa', label: 'Villa', icon: Icons.house_rounded),
    _HomeTypeOption(value: 'building', label: 'Building', icon: Icons.domain_rounded),
    _HomeTypeOption(value: 'office', label: 'Office', icon: Icons.business_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  bool get _needsFloors => _selectedType != 'flat';

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      await ref.read(homeSetupControllerProvider.notifier).createHome(
            name: _nameController.text.trim(),
            homeType: _selectedType,
            floorCount: _needsFloors ? _floorCount : 0,
            networkSsid: _ssidController.text.trim(),
            networkPassword: _passwordController.text,
          );

      if (!mounted) return;

      // Update homeIdProvider with newly created home
      final createdHome = ref.read(homeSetupControllerProvider).createdHome;
      if (createdHome != null) {
        ref.read(homeIdProvider.notifier).state = createdHome.id;
      }

      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      final err = ref.read(homeSetupControllerProvider).error;
      context.showErrorSnackBar(err ?? 'Failed to create home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final setupState = ref.watch(homeSetupControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(isDark),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(isDark)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  sliver: SliverToBoxAdapter(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Home Name Field
                          _SectionLabel(label: 'Home Name'),
                          const SizedBox(height: 8),
                          _buildNameField(isDark),
                          const SizedBox(height: 32),

                          // Home Type Selector
                          _SectionLabel(label: 'Type of Home'),
                          const SizedBox(height: 12),
                          _buildTypeSelector(isDark),
                          const SizedBox(height: 32),

                          // Floor Count (conditional)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _needsFloors
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _SectionLabel(label: 'Number of Floors'),
                                      const SizedBox(height: 12),
                                      _buildFloorStepper(isDark),
                                      const SizedBox(height: 32),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // Wi-Fi Network Section
                          _SectionLabel(
                            label: 'Wi-Fi Network',
                            subtitle: 'Optional — used for device provisioning',
                          ),
                          const SizedBox(height: 12),
                          _buildNetworkFields(isDark),
                          const SizedBox(height: 48),

                          // Submit Button
                          _buildSubmitButton(setupState, isDark),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              'You can change these settings anytime',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 20),
          Text('Set Up Your Home', style: AppTypography.h1),
          const SizedBox(height: 8),
          Text(
            'Tell us about your space so we can organize your smart devices perfectly.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary(isDark),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(bool isDark) {
    return TextFormField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary(isDark)),
      decoration: _inputDecoration(
        isDark: isDark,
        hint: 'e.g. My Home, Family Villa…',
        prefixIcon: Icons.label_outline_rounded,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Please enter a home name';
        if (v.trim().length < 2) return 'Name must be at least 2 characters';
        return null;
      },
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: _homeTypes.map((option) {
        final isSelected = _selectedType == option.value;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedType = option.value;
              // Reset floor count default when switching type
              if (option.value != 'flat') _floorCount = 2;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primaryLight,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : AppColors.primary.withValues(alpha: 0.05),
                        isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : AppColors.primary.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.borderColor(isDark),
                width: isSelected ? 0 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    option.icon,
                    size: 28,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                  Text(
                    option.label,
                    style: AppTypography.titleSmall.copyWith(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFloorStepper(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(isDark)),
      ),
      child: Row(
        children: [
          Icon(Icons.layers_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _floorCount == 1 ? '1 Floor' : '$_floorCount Floors',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary(isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.remove_rounded,
            onTap: () {
              if (_floorCount > 1) {
                HapticFeedback.selectionClick();
                setState(() => _floorCount--);
              }
            },
            enabled: _floorCount > 1,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              '$_floorCount',
              style: AppTypography.h3.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 8),
          _StepperButton(
            icon: Icons.add_rounded,
            onTap: () {
              if (_floorCount < 50) {
                HapticFeedback.selectionClick();
                setState(() => _floorCount++);
              }
            },
            enabled: _floorCount < 50,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkFields(bool isDark) {
    return Column(
      children: [
        TextFormField(
          controller: _ssidController,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary(isDark)),
          decoration: _inputDecoration(
            isDark: isDark,
            hint: 'Wi-Fi Network Name (SSID)',
            prefixIcon: Icons.wifi_rounded,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordController,
          obscureText: !_showPassword,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary(isDark)),
          decoration: _inputDecoration(
            isDark: isDark,
            hint: 'Wi-Fi Password',
            prefixIcon: Icons.lock_outline_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.textSecondary(isDark),
                size: 20,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(HomeSetupState state, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: state.isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: state.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Create Home',
                      style: AppTypography.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required bool isDark,
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyLarge.copyWith(
        color: AppColors.textSecondary(isDark).withValues(alpha: 0.6),
      ),
      prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : AppColors.primary.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.borderColor(isDark)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.borderColor(isDark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _HomeTypeOption {
  final String value;
  final String label;
  final IconData icon;

  const _HomeTypeOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? subtitle;

  const _SectionLabel({required this.label, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary(isDark),
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool isDark;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.borderColor(isDark).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? AppColors.primary
              : AppColors.textSecondary(isDark).withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
