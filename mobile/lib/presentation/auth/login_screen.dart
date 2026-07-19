import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/auth.controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/extensions.dart';
import '../common/widgets/app_button.dart';
import '../common/widgets/app_screen_wrapper.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/social_button.dart';
import 'widgets/auth_header.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      await ref.read(authControllerProvider.notifier).sendOtp(_phoneController.text.trim());
      if (!mounted) return;
      context.push(
        '/otp-verify',
        extra: {
          'contact': _phoneController.text.trim(),
          'is_email': false,
          'purpose': 'otp_login',
          'name': _nameController.text.trim(),
        },
      );
    } catch (_) {}
  }

  Future<void> _googleSignIn() async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
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
      useSafeArea: true,
      child: FadeTransition(
        opacity: _fadeAnim,
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
                    Center(
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/logo_3547.png',
                            height: 64,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Neuro Touch',
                            style: AppTypography.h2.copyWith(
                              letterSpacing: 1.2,
                              color: AppColors.textPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    const AuthHeader(
                      title: 'Welcome Back',
                      subtitle: 'Sign in to your smart home dashboard',
                    ),
                    const SizedBox(height: 32),
                    AuthTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                      validator: Validators.validatePhone,
                      hint: '+91 00000 00000',
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Optional for registration',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 32),
                    AppButton(
                      label: 'Continue',
                      onPressed: _sendOtp,
                      isLoading: authState.isLoading,
                    ),
                    const SizedBox(height: 24),
                    const Row(
                      children: [
                        Expanded(child: Divider(thickness: 0.5)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                        Expanded(child: Divider(thickness: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SocialButton(
                            label: 'Google',
                            assetPath: 'assets/images/Google__G__logo.svg.webp',
                            onTap: _googleSignIn,
                            isLoading: authState.isLoading,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SocialButton(
                            label: 'Apple',
                            icon: Icons.apple,
                            onTap: () => context.showInfoSnackBar('Coming soon'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary(isDark),
                          ),
                          children: [
                            const TextSpan(text: 'By continuing, you agree to our '),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
