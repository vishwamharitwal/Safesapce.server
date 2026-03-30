import 'package:flutter/material.dart';
import 'package:dilse/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class CrisisResourcesScreen extends StatelessWidget {
  const CrisisResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crisis Resources', 
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: 18,
          )
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.redAccent.withValues(alpha: 0.15),
                    Colors.redAccent.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                   Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Emergency Situation?',
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 20, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'If you or someone else is in immediate danger, please call your local emergency services (like 911 or 999) right away.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), 
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'GLOBAL HELPLINES',
              style: TextStyle(
                color: Colors.white38, 
                fontSize: 12, 
                fontWeight: FontWeight.bold, 
                letterSpacing: 2.0
              ),
            ),
            const SizedBox(height: 20),
            _buildResourceCard(
              title: '988 Suicide & Crisis Lifeline',
              subtitle: 'Free, confidential support for people in distress, 24/7.',
              phone: '988',
              color: Colors.blueAccent,
            ),
            _buildResourceCard(
              title: 'Crisis Text Line',
              subtitle: 'Connect with a volunteer Crisis Counselor at any time.',
              phone: '741741',
              isText: true,
              color: Colors.tealAccent,
            ),
            _buildResourceCard(
              title: 'The Trevor Project',
              subtitle: 'Crisis intervention and suicide prevention for LGBTQ youth.',
              phone: '1-866-488-7386',
              color: Colors.purpleAccent,
            ),
            _buildResourceCard(
              title: 'SAMHSA National Helpline',
              subtitle: 'Confidential treatment referral and information service.',
              phone: '1-800-662-4357',
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'You are not alone. Help is available.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceCard({
    required String title,
    required String subtitle,
    required String phone,
    bool isText = false,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final Uri url = Uri.parse(isText ? 'sms:$phone' : 'tel:$phone');
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title, 
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                          fontSize: 16,
                        )
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle, 
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5), 
                          fontSize: 13,
                          height: 1.4,
                        )
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isText ? Icons.message_rounded : Icons.phone_rounded, 
                    color: color, 
                    size: 24
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
