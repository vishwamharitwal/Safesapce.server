import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/session/presentation/pages/active_session_screen.dart';
import 'package:flutter_application_1/features/session/data/signaling_service.dart';

class MatchmakingScreen extends StatefulWidget {
  final String role;
  final String topic;

  const MatchmakingScreen({super.key, required this.role, required this.topic});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  final SignalingService _signalingService = SignalingService();
  String _statusMessage = 'Connecting to server...';

  @override
  void initState() {
    super.initState();
    _initSignaling();
  }

  void _initSignaling() {
    _signalingService.onWaitingForMatch = () {
      if (mounted) {
        setState(() {
          _statusMessage = 'Waiting for someone to connect...';
        });
      }
    };

    _signalingService.onMatchFound = (message) {
      if (mounted) {
        _hasMatched = true;
        // Pass the service to the active session screen so it can manage the call
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ActiveSessionScreen(signalingService: _signalingService),
          ),
        );
      }
    };

    _signalingService.connect();
    // Short delay to ensure socket connects before emitting
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _signalingService.findMatch(widget.role, widget.topic);
      }
    });
  }

  bool _hasMatched = false;

  @override
  void dispose() {
    if (!_hasMatched) {
      _signalingService.disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simplified ring representation replacing flutter_animate to avoid issues if not fully setup
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBackground, width: 2),
                color: AppColors.background,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.05),
                    spreadRadius: 30,
                    blurRadius: 40,
                  ),
                ],
              ),
              child: const Center(
                child: Text('✨', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'Finding someone for you...',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
