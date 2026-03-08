import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/session/data/signaling_service.dart';
import 'package:flutter_application_1/features/session/presentation/pages/active_session_screen.dart';
import 'package:flutter_application_1/features/session/presentation/pages/matchmaking_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PartnerPreviewScreen extends StatefulWidget {
  final SignalingService signalingService;
  final String partnerId;
  final String partnerName;
  final String partnerAvatar;
  final double partnerRating;
  final String role;
  final String topic;
  final String myNickname;
  final String myAvatar;

  const PartnerPreviewScreen({
    super.key,
    required this.signalingService,
    required this.partnerId,
    required this.partnerName,
    required this.partnerAvatar,
    required this.partnerRating,
    required this.role,
    required this.topic,
    required this.myNickname,
    required this.myAvatar,
  });

  @override
  State<PartnerPreviewScreen> createState() => _PartnerPreviewScreenState();
}

class _PartnerPreviewScreenState extends State<PartnerPreviewScreen> {
  double _rating = 0.0;
  List<String> _tags = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  late String _partnerName;
  late String _partnerAvatar;
  int _timeLeft = 20;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _partnerName = widget.partnerName;
    _partnerAvatar = widget.partnerAvatar;
    _fetchPartnerDetails();

    // Auto-skip timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          } else {
            _timer?.cancel();
            if (!_isActionInProgress) {
              _handleSkip();
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPartnerDetails() async {
    try {
      final supabase = Supabase.instance.client;

      // Fetch rating, nickname, and avatar
      final profileRes = await supabase
          .from('profiles')
          .select('rating, nickname, avatar')
          .eq('id', widget.partnerId)
          .single();

      // Fetch tags
      final tagsRes = await supabase
          .from('user_ratings')
          .select('tag_selected')
          .eq('target_id', widget.partnerId);

      final tagCounts = <String, int>{};
      for (var row in tagsRes) {
        final tag = row['tag_selected'] as String?;
        if (tag != null && tag.isNotEmpty) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      final sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (mounted) {
        setState(() {
          _partnerName = profileRes['nickname'] ?? widget.partnerName;
          _partnerAvatar = profileRes['avatar'] ?? widget.partnerAvatar;
          _rating =
              (profileRes['rating'] as num?)?.toDouble() ??
              widget.partnerRating;
          _tags = sortedTags.map((e) => e.key).take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching partner details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleConnect() {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);
    _timer?.cancel();

    widget.signalingService.acceptMatch();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveSessionScreen(
          signalingService: widget.signalingService,
          partnerId: widget.partnerId,
          partnerName: _partnerName,
          partnerAvatar: _partnerAvatar,
        ),
      ),
    );
  }

  void _handleSkip() {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);
    _timer?.cancel();

    widget.signalingService.skipMatch();

    // Restart matchmaking search directly by pushing a new matchmaking screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MatchmakingScreen(
          role: widget.role,
          topic: widget.topic,
          nickname: widget.myNickname,
          avatar: widget.myAvatar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'New Match Found!',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'Someone is ready to listen about "${widget.topic}"\n($_timeLeft seconds to accept)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 48),

              // Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryAccent.withValues(
                              alpha: 0.1,
                            ),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _partnerAvatar,
                          style: const TextStyle(fontSize: 60),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _partnerName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 24,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Tags
                    if (_isLoading)
                      const CircularProgressIndicator(
                        color: AppColors.primaryAccent,
                      )
                    else if (_tags.isEmpty)
                      const Text(
                        'Verified DilSe Listener',
                        style: TextStyle(color: Colors.white38),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _tags
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryAccent.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: AppColors.primaryAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),

              const Spacer(),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isActionInProgress ? null : _handleSkip,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isActionInProgress ? null : _handleConnect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Connect',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
