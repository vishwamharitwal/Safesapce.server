import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/session/presentation/pages/active_session_screen.dart';
import 'package:flutter_application_1/features/session/presentation/pages/partner_preview_screen.dart';
import 'package:flutter_application_1/features/session/data/signaling_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MatchmakingScreen extends StatefulWidget {
  final String role;
  final String topic;
  final String nickname;
  final String avatar;

  const MatchmakingScreen({
    super.key,
    required this.role,
    required this.topic,
    required this.nickname,
    required this.avatar,
  });

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

    _signalingService.onMatchFound =
        (message, partnerId, partnerName, partnerAvatar, partnerRating) {
          if (mounted) {
            if (widget.role == 'talk') {
              _hasMatched = true;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PartnerPreviewScreen(
                    signalingService: _signalingService,
                    partnerId: partnerId,
                    partnerName: partnerName,
                    partnerAvatar: partnerAvatar,
                    partnerRating: partnerRating,
                    role: widget.role,
                    topic: widget.topic,
                    myNickname: widget.nickname,
                    myAvatar: widget.avatar,
                  ),
                ),
              );
            } else {
              // Listener stays and waits for decision
              setState(() {
                _statusMessage =
                    '$partnerName is viewing your profile...\nWaiting for connection...';
              });
            }
          }
        };

    _signalingService.onPartnerConnected = () {
      if (mounted && widget.role == 'listen') {
        _hasMatched = true;
        // Listener doesn't have partner identity from match_found sometimes depending on order,
        // but signaling_service match_found should have triggered and saved partnerId if added to the call
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveSessionScreen(
              signalingService: _signalingService,
              partnerId: _signalingService.partnerId ?? '',
              partnerName: _signalingService.partnerName ?? 'Friend',
              partnerAvatar: _signalingService.partnerAvatar ?? '👤',
            ),
          ),
        );
      }
    };

    _signalingService.onMatchSkipped = (msg) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Looking for someone else...';
        });
        // Restart search if skipped
        final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
        _signalingService.findMatch(
          widget.role,
          widget.topic,
          userId,
          nickname: widget.nickname,
          avatar: widget.avatar,
        );
      }
    };

    _signalingService.connect();
    // Short delay to ensure socket connects before emitting
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (mounted) {
        final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

        // Fetch current rating for accurate identity
        double rating = 0.0;
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('rating')
              .eq('id', userId)
              .single();
          rating = (profile['rating'] as num?)?.toDouble() ?? 0.0;
        } catch (e) {
          debugPrint('Error fetching rating for findMatch: $e');
        }

        _signalingService.findMatch(
          widget.role,
          widget.topic,
          userId,
          nickname: widget.nickname,
          avatar: widget.avatar,
          rating: rating,
        );
      }
    });
  }

  bool _hasMatched = false;

  @override
  void dispose() {
    if (!_hasMatched) {
      _signalingService.cancelMatchmaking();
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
                    color: Colors.white.withValues(alpha: 0.2),
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
