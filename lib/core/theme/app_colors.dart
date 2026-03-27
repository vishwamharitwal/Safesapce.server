import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0F1423); // Deep navy background
  static const Color cardBackground = Color(
    0xFF1B2030,
  ); // Slightly lighter for cards/buttons

  // Accents
  static const Color primaryAccent = Color(
    0xFF5ABCB8,
  ); // Cyan/Teal for primary actions
  static const Color secondaryAccent = Color(
    0xFFDF5753,
  ); // Muted red for end call/errors

  // Tag / Abstract colors
  static const Color tagPurple = Color(
    0xFF382F44,
  ); // For relationships/loneliness tags
  static const Color tagEarthy = Color(0xFF3B332F); // For stress/career tags
  static const Color tagTeal = Color(0xFF23353A); // For anxiety/other tags

  // Rewards
  static const Color rewardGold = Color(0xFFFFD700);
  static const Color rewardCardBackground = Color(0xFF1E2638);

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF919AA3); // Muted grey-blue text

  // Avatars
  static const Color avatarBubbleRight = Color(0xFF3F3038);
  static const Color avatarBubbleLeft = Color(0xFF332B3C);
}
