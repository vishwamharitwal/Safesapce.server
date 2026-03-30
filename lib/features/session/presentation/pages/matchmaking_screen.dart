import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dilse/core/theme/app_colors.dart';
import 'package:dilse/features/session/presentation/pages/active_session_screen.dart';
import 'package:dilse/features/session/data/signaling_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MatchmakingScreen extends StatefulWidget {
  final String role;
  final String topic;
  final String nickname;
  final String avatar;
  final int? targetTime;

  const MatchmakingScreen({
    super.key,
    required this.role,
    required this.topic,
    required this.nickname,
    required this.avatar,
    this.targetTime,
  });

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  final SignalingService _signalingService = SignalingService();
  String _statusMessage = 'Connecting to server...';
  bool _isReadyToJoin = false;
  String _targetPartnerId = '';
  String _targetPartnerName = '';
  String _targetPartnerAvatar = '';
  bool _hasMatched = false;
  Timer? _connectionCheckTimer;
  DateTime? _matchTime; // Track when the match was discovered

  @override
  void initState() {
    super.initState();
    _initSignaling();
    _startConnectionPolling();
  }

  void _startConnectionPolling() {
    _connectionCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Navigate ONLY when both Socket (signaling) and WebRTC (audio) are connected
      if (_signalingService.isPartnerConnectedState &&
          _signalingService.isWebRTCConnected &&
          !_hasMatched) {

        setState(() {
          _statusMessage = 'Voice connection established! Joining...';
          _isReadyToJoin = true;
        });

        _navigateToSession();
        return;
      }

      // --- 30s Timeout Check ---
      if (_matchTime != null && !_hasMatched) {
        final duration = DateTime.now().difference(_matchTime!);
        if (duration.inSeconds > 30) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _statusMessage = 'Connection failed. Please try again.';
              _matchTime = null;
            });
            // Go back
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) Navigator.pop(context);
            });
          }
        }
      }
    });
  }

  void _navigateToSession() {
    if (!mounted || _hasMatched) return;
    _hasMatched = true;
    _connectionCheckTimer?.cancel();

    final finalId = _targetPartnerId.isNotEmpty
        ? _targetPartnerId
        : (_signalingService.partnerId ?? '');
    final finalName = _targetPartnerName.isNotEmpty
        ? _targetPartnerName
        : (_signalingService.partnerName ?? 'Friend');
    final finalAvatar = _targetPartnerAvatar.isNotEmpty
        ? _targetPartnerAvatar
        : (_signalingService.partnerAvatar ?? '');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveSessionScreen(
          signalingService: _signalingService,
          partnerId: finalId,
          partnerName: finalName,
          partnerAvatar: finalAvatar,
          targetTime: widget.targetTime,
        ),
      ),
    );
  }

  void _initSignaling() {
    _signalingService.onWaitingForMatch = () {
      if (mounted) {
        setState(() {
          _statusMessage = 'Waiting for someone to connect...';
          _isReadyToJoin = false;
        });
      }
    };

    _signalingService.onMatchFound =
        (message, partnerId, partnerName, partnerAvatar, partnerRating, targetTime) {
          if (mounted) {
            _targetPartnerId = partnerId;
            _targetPartnerName = partnerName;
            _targetPartnerAvatar = partnerAvatar;

            // Direct connect approach: Both users automatically accept the match.
            setState(() {
              _statusMessage = 'Connecting with $partnerName...';
              _matchTime = DateTime.now(); // Start timeout clock
            });
            _signalingService.acceptMatch();

            // Navigate immediately without waiting for server confirmation
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _navigateToSession();
              }
            });
          }
        };

    _signalingService.onPartnerConnected = (data) {

      if (data != null && data is Map) {
        if (_targetPartnerId.isEmpty) {
          _targetPartnerId = data['partnerId']?.toString() ?? '';
          _targetPartnerName = data['partnerName']?.toString() ?? 'Someone';
          _targetPartnerAvatar = data['partnerAvatar']?.toString() ?? '';
        }
      }
      if (mounted) {
        setState(() {
          _statusMessage = 'Connection accepted! Your partner is ready.';
          _isReadyToJoin = true;
        });

        // Small delay to ensure state updates reflect before navigation
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _navigateToSession();
          }
        });
      }
    };

    _signalingService.onMatchSkipped = (msg) {
      if (mounted) {
        setState(() {
          _statusMessage =
              'Previous match skipped. Looking for someone else...';
          _isReadyToJoin = false;
        });
        final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
        _signalingService.findMatch(
          widget.role,
          widget.topic,
          userId,
          nickname: widget.nickname,
          avatar: widget.avatar,
          targetTime: widget.targetTime,
        );
      }
    };

    _startMatchmakingProcess();
  }

  Future<void> _startMatchmakingProcess() async {
    final error = await _signalingService.connect();
    
    if (error != null) {
      if (mounted) {
        setState(() => _statusMessage = error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _signalingService.disconnect();
                _startMatchmakingProcess();
              },
            ),
          ),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.pop(context);
        });
      }
      return;
    }
    
    bool connected = await _signalingService.waitForConnection(timeoutMs: 10000);
    if (!mounted) return;

    if (!connected) {
      if (mounted) {
        setState(() => _statusMessage = 'Connection failed. Please check network and retry.');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    setState(() => _statusMessage = 'Searching for a safe connection...');
    await _signalingService.registerUser();

    double rating = 0.0;
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('rating')
          .eq('id', userId)
          .single();
      rating = (profile['rating'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
    }

    _signalingService.findMatch(
      widget.role,
      widget.topic,
      userId,
      nickname: widget.nickname,
      avatar: widget.avatar,
      rating: rating,
      targetTime: widget.targetTime,
    );
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    if (!_hasMatched) {
      _signalingService.cancelMatchmaking();
      _signalingService.disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.background.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (_isReadyToJoin)
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryAccent.withValues(alpha: 0.1),
                    ),
                  ),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isReadyToJoin
                          ? AppColors.primaryAccent
                          : AppColors.cardBackground,
                      width: 3,
                    ),
                    color: AppColors.background,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isReadyToJoin
                                    ? AppColors.primaryAccent
                                    : Colors.white)
                                .withValues(alpha: 0.2),
                        spreadRadius: 20,
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isReadyToJoin
                          ? Icons.check_circle
                          : Icons.volunteer_activism,
                      size: 64,
                      color: _isReadyToJoin
                          ? AppColors.primaryAccent
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Text(
              _isReadyToJoin
                  ? 'Successfully Matched!'
                  : 'Finding someone for you...',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (_isReadyToJoin) ...[
              const SizedBox(height: 64),
              ElevatedButton(
                onPressed: _navigateToSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Join Safe Space',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
