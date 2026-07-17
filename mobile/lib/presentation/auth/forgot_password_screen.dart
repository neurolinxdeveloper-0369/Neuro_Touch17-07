import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/auth.controller.dart';
import '../../core/utils/extensions.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/auth_header.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String purpose;
  const ForgotPasswordScreen({super.key, this.purpose = 'forgot_password'});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
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
    final screenSize = MediaQuery.sizeOf(context);
    final authState = ref.watch(authControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.error != null && next.status == AuthStatus.error) {
        context.showErrorSnackBar(next.error!);
        ref.read(authControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.06,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
              ),
              SizedBox(height: screenSize.height * 0.02),

              if (!_sent) ...[
                const AuthHeader(
                  title: 'Forgot Password',
                  subtitle:
                      'Enter your email or phone to receive a one-time code',
                ),
                SizedBox(height: screenSize.height * 0.04),

                // Toggle
                Row(children: [
                  _TabChip(
                    label: 'Email',
                    isSelected: _isEmail,
                    onTap: () => setState(() => _isEmail = true),
                  ),
                  const SizedBox(width: 8),
                  _TabChip(
                    label: 'Phone',
                    isSelected: !_isEmail,
                    onTap: () => setState(() => _isEmail = false),
                  ),
                ]),
                const SizedBox(height: 12),

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
                    isDark: isDark,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _submit,
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
                            'Send OTP',
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ] else ...[
                // Success state
                Center(
                  child: Column(
                    children: [
                      SizedBox(height: screenSize.height * 0.06),
                      Container(
                        width: screenSize.width * 0.22,
                        height: screenSize.width * 0.22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B894).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          color: Color(0xFF00B894),
                          size: 48,
                        ),
                      ),
                      SizedBox(height: screenSize.height * 0.03),
                      Text(
                        'OTP Sent!',
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We\'ve sent a 6-digit code to\n${_contactController.text.trim()}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: isDark
                              ? const Color(0xFFB2BEC3)
                              : const Color(0xFF555E68),
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: screenSize.height * 0.05),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.push('/otp-verify', extra: {
                            'contact': _contactController.text.trim(),
                            'is_email': _isEmail,
                            'purpose': 'reset_password',
                          }),
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Enter OTP',
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => setState(() => _sent = false),
                        child: Text(
                          'Resend OTP',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF4C6FFF)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4C6FFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4C6FFF)
                : const Color(0xFF55595E),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFB2BEC3),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
