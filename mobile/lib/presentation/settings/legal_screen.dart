import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../common/widgets/app_screen_wrapper.dart';
import '../common/widgets/glass_panel.dart';

enum LegalType { terms, privacy }

class LegalScreen extends StatelessWidget {
  final LegalType type;

  const LegalScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final title = type == LegalType.terms ? 'Terms of Service' : 'Privacy Policy';

    return AppScreenWrapper(
      title: title,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: GlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last Updated: July 2026',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(isDark)),
              ),
              const SizedBox(height: 24),
              ...(type == LegalType.terms ? _termsContent(isDark) : _privacyContent(isDark)),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _termsContent(bool isDark) {
    return [
      _section('1. Acceptance of Terms', 
          'By downloading or using the Neuro Touch app, these terms will automatically apply to you. You should make sure therefore that you read them carefully before using the app.'),
      _section('2. Usage License', 
          'Neuro Touch grants you a personal, non-exclusive, non-transferable, limited license to use the App for your personal, non-commercial purposes strictly in accordance with the terms of this License.'),
      _section('3. IoT Device Control', 
          'The app allows you to control Neuro Touch smart home hardware. You are responsible for ensuring that the installation of such hardware complies with local safety regulations. Neuro Touch is not liable for damages resulting from improper hardware installation or network failures.'),
      _section('4. Prohibited Actions', 
          'You are not allowed to attempt to extract the source code of the app, translate the app into other languages, or make derivative versions. The app itself, and all the trademarks, copyright, database rights and other intellectual property rights related to it, still belong to Neuro Touch.'),
      _section('5. Service Modifications', 
          'We are committed to ensuring that the app is as useful and efficient as possible. For that reason, we reserve the right to make changes to the app or to charge for its services, at any time and for any reason.'),
    ];
  }

  List<Widget> _privacyContent(bool isDark) {
    return [
      _section('1. Information Collection', 
          'We collect information to provide better services to our users. This includes: Device IDs for IoT provisioning, phone numbers for authentication, and usage logs for automation optimization.'),
      _section('2. How We Use Data', 
          'The data collected is used to manage your smart home devices, provide real-time alerts, and improve the machine learning models that power our AI assistant.'),
      _section('3. Data Security', 
          'We value your trust in providing us your Personal Information, thus we are striving to use commercially acceptable means of protecting it. Your user profile and tokens are stored in an encrypted secure vault on your device.'),
      _section('4. Third-party Services', 
          'The app does use third-party services that may collect information used to identify you. These include Google Play Services and Google Sign-In.'),
      _section('5. Children’s Privacy', 
          'These Services do not address anyone under the age of 13. We do not knowingly collect personally identifiable information from children under 13.'),
    ];
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            body,
            style: AppTypography.bodyMedium.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
