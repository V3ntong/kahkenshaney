import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Section(
                  heading: '1. Acceptance of Terms',
                  body:
                      'By accessing or using KAH KEN SHA NEY ("the App"), you '
                      'agree to be bound by these Terms & Conditions. If you do '
                      'not agree, please do not use the App.',
                ),
                _Section(
                  heading: '2. User Responsibilities',
                  body:
                      'You are responsible for maintaining the confidentiality of '
                      'your account credentials. You agree to provide accurate and '
                      'complete information during registration and to keep it '
                      'up to date. You must not share your account with others or '
                      'use another person\'s account without authorization.',
                ),
                _Section(
                  heading: '3. Privacy',
                  body:
                      'We collect and process personal data in accordance with our '
                      'Privacy Policy. By using the App, you consent to the '
                      'collection, use, and storage of your information as '
                      'described therein. Your data is stored securely using '
                      'Firebase and is never sold to third parties.',
                ),
                _Section(
                  heading: '4. AI Prediction Disclaimer',
                  body:
                      'The App uses artificial intelligence and machine learning '
                      'algorithms to match lost and found items. AI predictions '
                      'and confidence scores are estimates and should not be '
                      'treated as guarantees. We do not warrant the accuracy of '
                      'AI-generated suggestions. Always verify matches through '
                      'the appropriate channels.',
                ),
                _Section(
                  heading: '5. Image Upload Policy',
                  body:
                      'When you upload images of lost or found items, you confirm '
                      'that you have the right to share those images. Images are '
                      'processed by our AI system for matching purposes only. We '
                      'reserve the right to remove content that violates our '
                      'community guidelines or applicable laws.',
                ),
                _Section(
                  heading: '6. Account Responsibilities',
                  body:
                      'You must notify us immediately of any unauthorized use of '
                      'your account. We are not liable for any loss arising from '
                      'unauthorized use. We reserve the right to suspend or '
                      'terminate accounts that violate these terms.',
                ),
                _Section(
                  heading: '7. Limitation of Liability',
                  body:
                      'To the maximum extent permitted by law, KAH KEN SHA NEY '
                      'and its operators shall not be liable for any indirect, '
                      'incidental, special, or consequential damages arising from '
                      'your use of the App. The App is provided "as is" without '
                      'warranties of any kind, either express or implied.',
                ),
                _Section(
                  heading: '8. Changes to Terms',
                  body:
                      'We may update these Terms & Conditions from time to time. '
                      'Material changes will be communicated through the App or '
                      'via email. Continued use after changes constitutes '
                      'acceptance of the updated terms.',
                ),
                _Section(
                  heading: '9. Contact Information',
                  body:
                      'If you have questions about these Terms & Conditions, '
                      'please contact us at support@kahkenshaney.app.',
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.heading, required this.body});

  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
