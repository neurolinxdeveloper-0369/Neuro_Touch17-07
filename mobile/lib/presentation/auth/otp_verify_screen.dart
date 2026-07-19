import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/auth.controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../common/widgets/app_button.dart';
import '../common/widgets/app_screen_wrapper.dart';
import '../common/widgets/glass_panel.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String contact;
  final bool isEmail;
  final String purpose;
  final String? name;

  const OtpVerifyScreen({
    super.key,
    required this.contact,
    required this.isEmail,
    required this.purpose,
    this.name,
  });

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String get _otp => _controllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_otp.length == 6) _verify();
  }

  Future<void> _verify() async {
    try {
      await ref.read(authControllerProvider.notifier).verifyOtpLogin(
            phone: widget.contact,
            otp: _otp,
            name: widget.name,
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final authState = ref.watch(authControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.error != null && next.status == AuthStatus.error) {
        context.showErrorSnackBar(next.error!);
        ref.read(authControllerProvider.notifier).clearError();
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
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
                Text('Verification', style: AppTypography.h1),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                    children: [
                      const TextSpan(text: 'Enter the 6-digit code sent to\n'),
                      TextSpan(
                        text: widget.contact,
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _OtpBox(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          onChanged: (v) => _onChanged(index, v),
                          isDark: isDark,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 48),
                AppButton(
                  label: 'Verify & Proceed',
                  onPressed: _verify,
                  isLoading: authState.isLoading,
                ),
                const SizedBox(height: 24),
                Center(
                  child: AppButton(
                    label: 'Resend Code',
                    type: AppButtonType.text,
                    onPressed: () => context.pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onChanged;
  final bool isDark;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      opacity: 0.05,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        onChanged: onChanged,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppTypography.h2,
        decoration: const InputDecoration(
          counterText: '',
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
