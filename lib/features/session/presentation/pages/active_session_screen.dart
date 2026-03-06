import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/session/presentation/pages/post_session_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_application_1/features/session/data/signaling_service.dart';

class ActiveSessionScreen extends StatefulWidget {
  final SignalingService signalingService;

  const ActiveSessionScreen({super.key, required this.signalingService});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  int _secondsRemaining = 8 * 60; // 8 minutes
  Timer? _timer;
  bool _isMuted = false;

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  @override
  void initState() {
    super.initState();
    startTimer();

    widget.signalingService.onPartnerLeft = () {
      if (mounted) {
        _endSession(isPartnerLeft: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your partner has left the safe space.'),
          ),
        );
      }
    };
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      } else {
        _timer?.cancel();
        _endSession();
      }
    });
  }

  void _endSession({bool isPartnerLeft = false, bool isReport = false}) {
    // Notify the backend and WebRTC logic to close the room
    final roomId = widget.signalingService.currentRoomId ?? '';
    if (!isPartnerLeft) {
      widget.signalingService.leaveSession(roomId);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PostSessionScreen(
          isEarlyExit: _secondsRemaining > 0,
          isUserReported: isReport,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    final roomId = widget.signalingService.currentRoomId;
    if (roomId != null) {
      widget.signalingService.leaveSession(roomId);
    }
    super.dispose();
  }

  String get timerText {
    int minutes = _secondsRemaining ~/ 60;
    int seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Report User'),
        content: const Text(
          'Are you sure you want to report this user? This will end the session immediately and block them from matching with you again.',
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
              backgroundColor: AppColors.secondaryAccent,
            ),
            onPressed: () {
              Navigator.pop(context);
              _endSession(isReport: true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User has been reported.')),
              );
            },
            child: const Text('Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(String number) async {
    final Uri url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Emergency Helplines'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If you or someone else is in immediate danger, please reach out for help.',
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone, color: AppColors.primaryAccent),
              title: const Text('National Emergency Number'),
              subtitle: const Text('112'),
              onTap: () => _makeCall('112'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone, color: AppColors.primaryAccent),
              title: const Text('Mental Health Helpline (KIRAN)'),
              subtitle: const Text('1800-599-0019'),
              onTap: () => _makeCall('18005990019'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.warning_amber_rounded),
                            color: AppColors.secondaryAccent,
                            onPressed: () => _showEmergencyDialog(context),
                          ),
                          TextButton(
                            onPressed: () => _showReportDialog(context),
                            child: const Text(
                              'Report user',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0, bottom: 40.0),
                      child: Text(
                        'Speaking with your partner...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ),

                    // Giant Timer Circle
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryAccent,
                          width: 8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryAccent.withOpacity(0.15),
                            spreadRadius: 20,
                            blurRadius: 40,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          timerText,
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(fontSize: 56, letterSpacing: 2),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                Column(
                  children: [
                    // Avatars Row
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _AvatarWidget(
                          label: 'You',
                          icon: '🐰',
                          bgColor: AppColors.avatarBubbleLeft,
                        ),
                        SizedBox(width: 16),
                        _ConnectionDots(),
                        SizedBox(width: 16),
                        _AvatarWidget(
                          label: 'Friend',
                          icon: '🦊',
                          bgColor: AppColors.avatarBubbleRight,
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Controls Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ControlButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic_none,
                          color: _isMuted
                              ? AppColors.secondaryAccent
                              : AppColors.cardBackground,
                          iconColor: _isMuted
                              ? Colors.white
                              : AppColors.textSecondary,
                          onTap: _toggleMute,
                        ),
                        const SizedBox(width: 32),
                        _ControlButton(
                          icon: Icons.phone_disabled,
                          color: AppColors.secondaryAccent,
                          iconColor: Colors.white,
                          onTap: _endSession,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ), // Closes Column 264
              ], // Closes children padding 190
            ), // Closes Column 188
          ), // Closes Container 181
        ), // Closes SingleScroll 180
      ), // Closes SafeArea 179
    ); // Closes Scaffold 178
  }
}

class _AvatarWidget extends StatelessWidget {
  final String label;
  final String icon;
  final Color bgColor;

  const _AvatarWidget({
    required this.label,
    required this.icon,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
      ],
    );
  }
}

class _ConnectionDots extends StatelessWidget {
  const _ConnectionDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.textSecondary,
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 24,
          height: 2,
          color: AppColors.textSecondary.withOpacity(0.3),
        ),
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.textSecondary,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }
}
