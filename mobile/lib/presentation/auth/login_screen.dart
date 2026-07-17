import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/auth.controller.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/extensions.dart';
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

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF06457F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Terms & Conditions',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Updated: July 17, 2026\n',
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Welcome to Neuro Touch. Please read these Terms & Conditions ("Terms") carefully before using our mobile application and IoT services.\n\n'
                    '1. Acceptance of Terms\n'
                    'By accessing or using the Neuro Touch mobile application, you agree to be bound by these Terms and our Privacy Policy. If you do not agree, please do not use the application.\n\n'
                    '2. Description of Service\n'
                    'Neuro Touch provides a secure IoT (Internet of Things) dashboard allowing users to provision, manage, monitor, and automate smart home devices. Services include real-time device control, automated task scheduling, and intelligent automation chat support.\n\n'
                    '3. Account Registration & Security\n'
                    'To use the application, you must authenticate using your phone number or valid social credentials. You are responsible for keeping your login credentials confidential and for all activities that occur under your account.\n\n'
                    '4. Device Provisioning & Network Security\n'
                    'Provisioning smart home devices (via SoftAP or local network setups) requires configuring connection parameters. You are solely responsible for securing your local wireless network (Wi-Fi) and ensuring that your IoT devices are deployed in a safe manner.\n\n'
                    '5. Prohibited Activities\n'
                    'You agree not to attempt to reverse engineer, decompile, or bypass security features of the app or connected hardware, use the service for any illegal purposes, or impersonate another user.\n\n'
                    '6. Limitation of Liability\n'
                    'Neuro Touch, its developers, and affiliates shall not be liable for any direct, indirect, incidental, or consequential damages resulting from hardware failures, network outages, unauthorized access, or inaccuracies in automated actions.\n\n'
                    '7. Modifications to Service and Terms\n'
                    'We reserve the right to modify or discontinue the service, or amend these Terms at any time. Continued use of the application constitutes acceptance of updated Terms.',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF06457F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Privacy Policy',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Updated: July 17, 2026\n',
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'At Neuro Touch, we value your privacy. This Privacy Policy describes how we collect, use, store, and share your personal information.\n\n'
                    '1. Information We Collect\n'
                    'We collect the following data to provide and improve our services:\n'
                    '• Authentication Data: Phone numbers, OTP codes, or Social Sign-in profiles (name and profile picture URL).\n'
                    '• Device Details: Wi-Fi networks (SSID/BSSID) during provisioning, and status diagnostics of connected IoT smart devices.\n'
                    '• Local Storage: Secure tokens, local preferences, and offline cache are saved locally using secure storage.\n\n'
                    '2. How We Use Information\n'
                    'We use the collected information for user authentication, provisioning and controlling local and remote IoT hardware, providing AI assistant automation, and improving app performance.\n\n'
                    '3. Data Storage & Security\n'
                    'Your data is securely stored locally on your device and transmitted to our cloud servers using SSL/TLS encryption. We implement administrative and technical measures to protect your data from unauthorized access.\n\n'
                    '4. Data Sharing\n'
                    'We do not sell, rent, or trade your personal information. We may share data only to comply with legal obligations or protect user safety.\n\n'
                    '5. Your Rights & Choices\n'
                    'You have control over your data. You can update your profile name/avatar via Settings, request complete account deletion, or clear your local cache at any time.',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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

    // Forced dark/black background and white text for the login screen
    const bgColor = Color(0xFF000000);

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
                    // Centered Logo and Brand Name
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/logo_3547.png',
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Neuro Touch',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 140,
                            height: 2,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Header (Forced white text, brand accent hidden)
                    const AuthHeader(
                      title: 'Welcome',
                      subtitle: 'Sign in or sign up using your phone number or social accounts',
                      isForceDark: true,
                      showBrandAccent: false,
                    ),

                    const SizedBox(height: 24),

                    // Phone field
                    AuthTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                      validator: Validators.validatePhone,
                      isDark: true,
                    ),

                    const SizedBox(height: 16),

                    // Name field (Optional)
                    AuthTextField(
                      controller: _nameController,
                      label: 'Full Name (Optional for first-time sign up)',
                      keyboardType: TextInputType.name,
                      prefixIcon: Icons.person_outline_rounded,
                      isDark: true,
                    ),

                    const SizedBox(height: 20),

                    // Send OTP button (bg #06457F, text white)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06457F),
                          foregroundColor: Colors.white,
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
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Divider
                    const Row(children: [
                      Expanded(child: Divider(color: Colors.white30)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or continue with',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13, fontFamily: 'Inter'),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white30)),
                    ]),

                    const SizedBox(height: 20),

                    // Social login buttons
                    Row(
                      children: [
                        Expanded(
                          child: SocialButton(
                            label: 'Google',
                            assetPath: 'assets/images/Google__G__logo.svg.webp',
                            onTap: _googleSignIn,
                            isDark: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SocialButton(
                            label: 'Apple',
                            icon: Icons.apple,
                            onTap: () {
                              context.showInfoSnackBar('Sign in with Apple is not configured for this device yet.');
                            },
                            isDark: true,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Terms and Conditions / Privacy Policy and version at bottom
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _showTermsDialog(context),
                              child: const Text(
                                'Terms & Conditions',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white70,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                            const Text('  |  ', style: TextStyle(color: Colors.white30, fontSize: 12)),
                            GestureDetector(
                              onTap: () => _showPrivacyDialog(context),
                              child: const Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white70,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Neuro Touch V1.1',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
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
