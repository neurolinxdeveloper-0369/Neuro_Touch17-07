import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/auth.controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/extensions.dart';
import '../common/widgets/app_button.dart';
import '../common/widgets/app_screen_wrapper.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/auth_header.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isEmail = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authControllerProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _isEmail ? _contactController.text.trim() : null,
          phone: !_isEmail ? _contactController.text.trim() : null,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final authState = ref.watch(authControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.isAuthenticated) context.go('/dashboard');
      if (next.error != null && next.status == AuthStatus.error) {
        context.showErrorSnackBar(next.error!);
        ref.read(authControllerProvider.notifier).clearError();
      }
    });

    return AppScreenWrapper(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                    onPressed: () => context.pop(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 32),
                  const AuthHeader(
                    title: 'Create Account',
                    subtitle: 'Join Neuro Touch for a smarter living experience',
                  ),
                  const SizedBox(height: 40),
                  AuthTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    prefixIcon: Icons.person_outline_rounded,
                    validator: Validators.validateName,
                    hint: 'Your Name',
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _TabChip(
                        label: 'Email',
                        isSelected: _isEmail,
                        onTap: () => setState(() => _isEmail = true),
                      ),
                      const SizedBox(width: 12),
                      _TabChip(
                        label: 'Phone',
                        isSelected: !_isEmail,
                        onTap: () => setState(() => _isEmail = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _contactController,
                    label: _isEmail ? 'Email Address' : 'Phone Number',
                    keyboardType: _isEmail ? TextInputType.emailAddress : TextInputType.phone,
                    prefixIcon: _isEmail ? Icons.email_outlined : Icons.phone_outlined,
                    validator: _isEmail ? Validators.validateEmail : Validators.validatePhone,
                    hint: _isEmail ? 'email@example.com' : '+91 00000 00000',
                  ),
                  const SizedBox(height: 24),
                  AuthTextField(
                    controller: _passwordController,
                    label: 'Password',
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppColors.textSecondary(isDark),
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: Validators.validatePassword,
                    hint: '••••••••',
                  ),
                  const SizedBox(height: 24),
                  AuthTextField(
                    controller: _confirmController,
                    label: 'Confirm Password',
                    obscureText: _obscureConfirm,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppColors.textSecondary(isDark),
                      ),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: (v) => Validators.validateConfirmPassword(v, _passwordController.text),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    hint: '••••••••',
                  ),
                  const SizedBox(height: 40),
                  AppButton(
                    label: 'Create Account',
                    onPressed: _submit,
                    isLoading: authState.isLoading,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary(isDark),
                        ),
                        children: [
                          const TextSpan(text: 'By creating an account, you agree to our '),
                          TextSpan(
                            text: 'Terms',
                            style: TextStyle(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => context.push('/legal?type=terms'),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => context.push('/legal?type=privacy'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(isDark)),
                        ),
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Text(
                            'Sign In',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBackground(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderColor(isDark),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textPrimary(isDark),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
