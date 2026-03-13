import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';

class CrisisManager {
  static const List<String> _crisisKeywords = [
    'suicide',
    'jeena nahi',
    'mar jana',
    'marne ka mann',
    'zindagi khatam',
    'die',
    'kill myself',
    'end my life',
    'hurt myself',
    'chhat se kood',
    'nas kaat',
    'poison',
    'zeher',
    'pankhe se',
  ];

  static bool isCrisis(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    return _crisisKeywords.any((word) => lower.contains(word));
  }

  static void showCrisisDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.favorite, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'You are not alone 🫂',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "It sounds like you're going through a lot. Please know that your life matters and help is always available.",
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Text(
              "Helpline (India):",
              style: TextStyle(
                color: AppColors.primaryAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Vandrevala Foundation: 91-9999 666 555",
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 8),
            Text("iCall: 9152987821", style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'I am safe now',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final Uri telLaunchUri = Uri(scheme: 'tel', path: '919999666555');
              launchUrl(telLaunchUri);
            },
            child: const Text(
              'Call Helpline',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
