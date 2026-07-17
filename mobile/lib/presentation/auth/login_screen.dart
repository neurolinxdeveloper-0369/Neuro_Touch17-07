import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/auth.controller.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/extensions.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/social_button.dart';
import 'widgets/auth_header.dart';

const Color _darkBg = Color(0xFF010817);
const Color _borderDark = Color(0xFF55595E);
const Color _darkTextSecondary = Color(0xFFB2BEC3);
const Color _lightTextSecondary = Color(0xFF555E68);
const Color _borderLight = Color(0xFFD1D5DB);

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
      duration: const Duration(milliseconds: 600),
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
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    
    try {
      await ref.read(authControllerProvider.notifier).sendOtp(phone);
      if (!mounted) return;
      context.push(
        '/otp-verify',
        extra: {
          'contact': phone,
          'is_email': false,
          'purpose': 'otp_login',
          'name': name,
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
    final screenSize = MediaQuery.sizeOf(context);
    final authState = ref.watch(authControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.isAuthenticated) {
        context.go('/dashboard');
      }
      if (next.error != null && next.status == AuthStatus.error) {
        context.showErrorSnackBar(next.error!);
        ref.read(authControllerProvider.notifier).clearError();
      }
    });

    final bgColor = isDark ? _darkBg : Colors.white;
    final textSecondary = isDark ? _darkTextSecondary : _lightTextSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.06,
                vertical: 16,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: screenSize.height * 0.02),

                    // Header
                    const AuthHeader(
                      title: 'Welcome to Neuro Touch',
                      subtitle: 'Sign in or sign up using your phone number or Google account',
                    ),

                    SizedBox(height: screenSize.height * 0.04),

                    // Phone field
                    AuthTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                      validator: Validators.validatePhone,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 16),

                    // Name field (Optional)
                    AuthTextField(
                      controller: _nameController,
                      label: 'Full Name (Optional for first-time sign up)',
                      keyboardType: TextInputType.name,
                      prefixIcon: Icons.person_outline_rounded,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 24),

                    // Send OTP button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                'Send OTP Verification',
                                style: GoogleFonts.inter(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Divider
                    Row(children: [
                      Expanded(child: Divider(color: isDark ? _borderDark : _borderLight)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or continue with',
                          style: GoogleFonts.inter(
                              color: textSecondary, fontSize: 13),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? _borderDark : _borderLight)),
                    ]),

                    const SizedBox(height: 24),

                    // Google Social button
                    SocialButton(
                      label: 'Continue with Google',
                      assetPath: 'assets/images/google_logo.png',
                      onTap: _googleSignIn,
                      isDark: isDark,
                    ),

                    SizedBox(height: context.padding.bottom + 16),
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


