import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/auth.controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../common/widgets/app_button.dart';
import '../common/widgets/app_screen_wrapper.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/auth_header.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String purpose;
  const ForgotPasswordScreen({super.key, this.purpose = 'forgot_password'});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contactController = TextEditingController();
  bool _isEmail = true;
  bool _sent = false;

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await ref
        .read(authControllerProvider.notifier)
        .forgotPassword(
          contact: _contactController.text.trim(),
          isEmail: _isEmail,
        );
    if (success && mounted) {
      setState(() => _sent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final authState = ref.watch(authControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                  onPressed: () => context.pop(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 32),

                if (!_sent) ...[
                  const AuthHeader(
                    title: 'Reset Password',
                    subtitle: 'Enter your details to receive a recovery code',
                  ),
                  const SizedBox(height: 40),

                  Row(children: [
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
                  ]),
                  const SizedBox(height: 24),

                  Form(
                    key: _formKey,
                    child: AuthTextField(
                      controller: _contactController,
                      label: _isEmail ? 'Email Address' : 'Phone Number',
                      keyboardType: _isEmail
                          ? TextInputType.emailAddress
                          : TextInputType.phone,
                      prefixIcon: _isEmail
                          ? Icons.email_outlined
                          : Icons.phone_outlined,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return _isEmail
                              ? 'Email is required'
                              : 'Phone is required';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),

                  const SizedBox(height: 40),

                  AppButton(
                    label: 'Send Recovery Code',
                    onPressed: _submit,
                    isLoading: authState.isLoading,
                  ),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 48),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mark_email_read_outlined,
                            color: AppColors.success,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Code Sent!',
                          style: AppTypography.h2,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'We\'ve sent a verification code to\n${_contactController.text.trim()}',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                        const SizedBox(height: 48),
                        AppButton(
                          label: 'Enter Code',
                          onPressed: () => context.push('/otp-verify', extra: {
                            'contact': _contactController.text.trim(),
                            'is_email': _isEmail,
                            'purpose': 'reset_password',
                          }),
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'Resend Code',
                          type: AppButtonType.text,
                          onPressed: () => setState(() => _sent = false),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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
