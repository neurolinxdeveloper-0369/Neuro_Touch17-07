import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late Timer _carouselTimer;

  bool _isFormValid = false;
  bool _agreedToTerms = false;
  int _currentQuoteIndex = 0;
  final List<String> _quotes = [
    "Smart living, simplified.",
    "Control your home with a touch.",
    "Experience the future today."
  ];

  void _validateForm() {
    final isValid = _phoneController.text.trim().length >= 10;
    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

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
    
    _phoneController.addListener(_validateForm);

    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentQuoteIndex = (_currentQuoteIndex + 1) % _quotes.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer.cancel();
    _phoneController.removeListener(_validateForm);
    _phoneController.dispose();
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
          'name': '', // Removed name field
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
      scrollable: false,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Container(
                    width: constraints.maxWidth * 0.9,
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Form(
                      key: _formKey,
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton(
                                onPressed: () => context.showInfoSnackBar('Demo mode coming soon'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryLight,
                                  side: const BorderSide(color: AppColors.primaryLight),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text('Explore Demo'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/logo_3547.png',
                                  height: 48,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Neuro Touch',
                                  style: context.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary(isDark),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 800),
                                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                                  child: Text(
                                    _quotes[_currentQuoteIndex],
                                    key: ValueKey<int>(_currentQuoteIndex),
                                    style: context.textTheme.bodyLarge?.copyWith(
                                      color: AppColors.textSecondary(isDark),
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 48),
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
                                const SizedBox(width: 16),
                                Expanded(
                                  child: SocialButton(
                                    label: 'Apple',
                                    icon: Icons.apple,
                                    onTap: () => context.showInfoSnackBar('Coming soon'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            const Row(
                              children: [
                                Expanded(child: Divider(thickness: 0.5)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('Or', style: TextStyle(color: Colors.grey, fontSize: 14)),
                                ),
                                Expanded(child: Divider(thickness: 0.5)),
                              ],
                            ),
                            const SizedBox(height: 32),
                            AuthTextField(
                              controller: _phoneController,
                              label: 'Phone Number',
                              keyboardType: TextInputType.phone,
                              validator: Validators.validatePhone,
                              hint: '+91 ',
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _agreedToTerms,
                                    onChanged: (val) {
                                      setState(() {
                                        _agreedToTerms = val ?? false;
                                      });
                                    },
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary(isDark),
                                        height: 1.4,
                                      ),
                                      children: [
                                        const TextSpan(text: 'By checking this box, I agree to the '),
                                        TextSpan(
                                          text: 'Terms and Conditions',
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
                                        const TextSpan(text: '.'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            AppButton(
                              label: 'Send OTP',
                              onPressed: (_isFormValid && _agreedToTerms) ? _sendOtp : null,
                              isLoading: authState.isLoading,
                            ),
                            const Spacer(),
                            const SizedBox(height: 32),
                            Center(
                              child: TextButton(
                                onPressed: () => context.showInfoSnackBar('Contact support'),
                                child: Text(
                                  'Need help? Contact us',
                                  style: TextStyle(
                                    color: AppColors.primaryLight,
                                    fontWeight: FontWeight.w600,
                                  ),
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
          },
        ),
      ),
    );
  }
}
