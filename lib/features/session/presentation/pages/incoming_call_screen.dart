import 'package:flutter/material.dart';
import 'package:dilse/core/theme/app_colors.dart';
import 'package:dilse/features/session/data/signaling_service.dart';

class IncomingCallScreen extends StatefulWidget {
  final Map<String, dynamic> callData;
  final SignalingService signalingService;

  const IncomingCallScreen({
    super.key,
    required this.callData,
    required this.signalingService,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // Listen for call cancelled/failed by caller
    widget.signalingService.onCallFailed = (message) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('Call ended: $message')));
      }
    };
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callerName = widget.callData['callerName'] ?? 'Someone';
    final callerAvatar = widget.callData['callerAvatar'] ?? '👤';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Incoming Call...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 20,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
                    width: 120 + (_animationController.value * 20),
                    height: 120 + (_animationController.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryAccent.withValues(alpha: 0.2),
                      border: Border.all(
                        color: AppColors.primaryAccent.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        callerAvatar,
                        style: const TextStyle(fontSize: 64),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Inviting you to an 8-minute session.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 64),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () {
                      widget.signalingService.declineCall(
                        widget.callData['callerSocketId'],
                      );
                      Navigator.pop(context);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.secondaryAccent,
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Decline',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      widget.signalingService.acceptCall(
                        widget.callData['callerSocketId'],
                      );
                      // Pop ringing screen; match_found event handles next step
                      Navigator.pop(context);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryAccent,
                          ),
                          child: const Icon(
                            Icons.call,
                            color: AppColors.background,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Accept',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
