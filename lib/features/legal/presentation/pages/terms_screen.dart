import 'package:flutter/material.dart';
import 'package:safespace/core/theme/app_colors.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Terms & Privacy'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              "Welcome to SafeSpace (DilSe)",
              "Safe Space is a platform for anonymous peer-to-peer emotional support. By using this application, you agree to these Terms and our Privacy Practices.",
            ),
            _buildSection(
              "🔞 Age Requirement",
              "You MUST be at least 18 years old to use this app. By proceeding, you confirm that you are an adult. We do not knowingly collect data from or allow access to users under 18.",
            ),
            _buildSection(
              "1. 100% Anonymity",
              "We do not store your real name, identity, or social profiles. Your conversations are peer-to-peer and transient. Our mission is to provide a judgment-free zone.",
            ),
            _buildSection(
              "2. Data Governance",
              "Thoughts posted on the 'Think' feed are automatically purged from our database after 24 hours. We do not sell your personal data or chat logs to any third parties.",
            ),
            _buildSection(
              "3. Strict Community Rules",
              "We have ZERO tolerance for harassment, hate speech, bullying, or sexual content. Automated filters and human reporting systems are in place to ban violators instantly.",
            ),
            _buildSection(
              "4. Crisis & Medical Disclaimer",
              "Safe Space is NOT a replacement for professional therapy or crisis intervention. If you are in immediate danger, having suicidal thoughts, or self-harming, please contact emergency services or the helpline immediately (Vandrevala Foundation: 91-9999 666 555).",
            ),
            _buildSection(
              "5. User Responsibility",
              "You are solely responsible for your interactions. We provide 'Report' and 'Block' tools to help you maintain your safety. Safe Space is not liable for user-generated content.",
            ),
            _buildSection(
              "6. Grievance Redressal",
              "For any concerns or reporting violations, you can contact our Grievance Officer at: support@safespaceapp.com",
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                "Last Updated: March 2026\nVersion 1.0.1 • Made for Humanity 🫂",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primaryAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white, // Improved visibility
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
