import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/home/presentation/pages/topic_selection_screen.dart';
import 'package:flutter_application_1/features/legal/presentation/pages/terms_screen.dart';
import 'package:flutter_application_1/core/services/presence_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String nickname;
  final String avatar;
  final VoidCallback onProfileTap;

  const RoleSelectionScreen({
    super.key,
    required this.nickname,
    required this.avatar,
    required this.onProfileTap,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // 0 for Talk, 1 for Listen, null for none
  int? _selectedRole;
  bool _isCrisisAcknowledged = false;
  PresenceService? _presenceService;

  @override
  void initState() {
    super.initState();
    final currentUser = Supabase.instance.client.auth.currentUser;
    final uniqueId =
        currentUser?.id ??
        '${widget.nickname}_${DateTime.now().millisecondsSinceEpoch}';
    _presenceService = PresenceService(userId: uniqueId);
    _presenceService!.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _presenceService?.dispose();
    super.dispose();
  }

  void _showListenerGuide() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Listener Guidelines'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'As a listener, you agree to:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• Just listen. You are NOT a therapist.'),
              SizedBox(height: 8),
              Text('• Do not give medical or psychiatric advice.'),
              SizedBox(height: 8),
              Text('• Be empathetic and non-judgmental.'),
              SizedBox(height: 8),
              Text('• Use the Report button if the user is abusive.'),
              SizedBox(height: 8),
              Text(
                '• Use the Emergency button if someone is in immediate danger.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TopicSelectionScreen(
                    role: 'listen',
                    nickname: widget.nickname,
                    avatar: widget.avatar,
                  ),
                ),
              );
            },
            child: const Text(
              'I Agree',
              style: TextStyle(color: AppColors.background),
            ),
          ),
        ],
      ),
    );
  }

  void _handleContinue() {
    if (_selectedRole == 1) {
      _showListenerGuide();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TopicSelectionScreen(
            role: 'talk',
            nickname: widget.nickname,
            avatar: widget.avatar,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar with Avatar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: widget.onProfileTap,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.avatar,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                "Hi, ${widget.nickname}",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Who are you right now?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: Colors.white60,
                ),
              ),

              const SizedBox(height: 12),

              // Talk Option
              Expanded(
                flex: 5,
                child: _RoleCard(
                  title: 'I want to talk',
                  subtitle: "Share what's on your mind",
                  icon: Icons.chat_bubble_outline,
                  baseColor: const Color(0xFF233C48),
                  iconColor: const Color(0xFF42D7C3),
                  isSelected: _selectedRole == 0,
                  onTap: () {
                    setState(() {
                      _selectedRole = 0;
                    });
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Listen Option
              Expanded(
                flex: 5,
                child: _RoleCard(
                  title: 'I want to listen',
                  subtitle: 'Be there for someone',
                  icon: Icons.headphones_outlined,
                  baseColor: const Color(0xFF2C2442),
                  iconColor: const Color(0xFFA773E8),
                  isSelected: _selectedRole == 1,
                  onTap: () {
                    setState(() {
                      _selectedRole = 1;
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Active Online Users Count
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF42D7C3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _presenceService?.onlineUsersCount == null
                        ? 'Connecting to safe space...'
                        : '${_presenceService!.onlineUsersCount} people are online right now',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Disclaimer & Crisis Acknowledgment Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _isCrisisAcknowledged,
                      activeColor:
                          AppColors.secondaryAccent, // Red accent for crisis
                      onChanged: (val) {
                        setState(() {
                          _isCrisisAcknowledged = val ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'If you are in a crisis or thinking about harming yourself, please use emergency help instead of this app.',
                          style: TextStyle(
                            color: AppColors.secondaryAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Disclaimer: This app is for peer-to-peer emotional support. It is NOT a professional therapy platform.',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Continue Button
              ElevatedButton(
                onPressed: (_selectedRole != null && _isCrisisAcknowledged)
                    ? _handleContinue
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: AppColors.background,
                  disabledBackgroundColor: AppColors.primaryAccent.withValues(alpha: 0.2),
                  disabledForegroundColor: AppColors.background.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TermsScreen()),
                    );
                  },
                  child: Text(
                    'Terms & Privacy Policy',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color baseColor;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.baseColor,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, isSelected ? -4 : 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? Border.all(color: iconColor, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.2),
                    blurRadius: 15,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
