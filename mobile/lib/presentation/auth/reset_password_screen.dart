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

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String resetToken;
  const ResetPasswordScreen({super.key, required this.resetToken});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await ref.read(authControllerProvider.notifier).resetPassword(
          resetToken: widget.resetToken,
          newPassword: _passwordController.text,
        );
    if (success && mounted) {
      context.showSuccessSnackBar('Password reset successfully!');
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final authState = ref.watch(authControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (_, next) {
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
                  Text('New Password', style: AppTypography.h1),
                  const SizedBox(height: 12),
                  Text(
                    'Create a secure password for your Neuro Touch account',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(isDark)),
                  ),
                  const SizedBox(height: 40),
                  AuthTextField(
                    controller: _passwordController,
                    label: 'New Password',
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
                    label: 'Confirm New Password',
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
                  const SizedBox(height: 48),
                  AppButton(
                    label: 'Reset Password',
                    onPressed: _submit,
                    isLoading: authState.isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
