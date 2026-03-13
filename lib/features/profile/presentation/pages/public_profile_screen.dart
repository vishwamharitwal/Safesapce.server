import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final String avatar;
  final String nickname;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    required this.avatar,
    required this.nickname,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isConnecting = false;
  bool _isRequestSent = false;

  double _rating = 5.0;
  int _totalTalks = 0;
  List<Map<String, dynamic>> _topTags = [];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchTags();
    _checkExistingRequest();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('rating, total_talks')
          .eq('id', widget.userId)
          .maybeSingle();

      if (mounted && response != null) {
        setState(() {
          _rating = (response['rating'] as num?)?.toDouble() ?? 5.0;
          _totalTalks = (response['total_talks'] as int?) ?? 0;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkExistingRequest() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;
    try {
      final existing = await _supabase
          .from('connections')
          .select('id')
          .or(
            'and(sender_id.eq.$currentUserId,receiver_id.eq.${widget.userId}),and(sender_id.eq.${widget.userId},receiver_id.eq.$currentUserId)',
          )
          .maybeSingle();
      if (mounted && existing != null) {
        setState(() => _isRequestSent = true);
      }
    } catch (_) {}
  }

  Future<void> _fetchTags() async {
    try {
      final response = await _supabase
          .from('user_ratings')
          .select('tag_selected')
          .eq('target_id', widget.userId);

      final tagCounts = <String, int>{};
      for (var row in response) {
        final tag = row['tag_selected'] as String?;
        if (tag != null && tag.isNotEmpty) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      final sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (mounted) {
        setState(() {
          _topTags = sortedTags
              .map((e) => {'tag': e.key, 'count': e.value})
              .take(10)
              .toList();
        });
      }
    } catch (_) {
      // Table might not exist yet, fail silently
    }
  }

  Future<void> _sendConnectionRequest() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    setState(() => _isConnecting = true);

    try {
      // Final check before sending to prevent duplicates
      final existing = await _supabase
          .from('connections')
          .select('id')
          .or(
            'and(sender_id.eq.$currentUserId,receiver_id.eq.${widget.userId}),and(sender_id.eq.${widget.userId},receiver_id.eq.$currentUserId)',
          )
          .maybeSingle();

      if (existing != null) {
        if (mounted) {
          setState(() => _isRequestSent = true);
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text('Connection already exists or requested.'),
              ),
            );
        }
        return;
      }

      await _supabase.from('connections').insert({
        'sender_id': currentUserId,
        'receiver_id': widget.userId,
        'status': 'pending',
      });

      if (mounted) {
        setState(() => _isRequestSent = true);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Connection request sent!')),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not send request. Please try again.'),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = _supabase.auth.currentUser?.id == widget.userId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.nickname,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),

                  // Large Avatar
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cardBackground,
                      border: Border.all(
                        color: AppColors.primaryAccent.withValues(alpha: 0.5),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.avatar,
                        style: const TextStyle(fontSize: 56),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Nickname
                  Text(
                    widget.nickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Trust badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_rating.toStringAsFixed(1)} Trust',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.people_alt_rounded,
                          iconColor: AppColors.primaryAccent,
                          label: 'Total Talks',
                          value: _totalTalks.toString(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.star_rounded,
                          iconColor: Colors.amber,
                          label: 'Trust Rating',
                          value: _rating.toStringAsFixed(1),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Trust Badges Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.local_police_rounded,
                              color: AppColors.primaryAccent,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Community Badges',
                              style: TextStyle(
                                color: AppColors.primaryAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_topTags.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _topTags.map((tagObj) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tagObj['tag'],
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryAccent
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${tagObj['count']}',
                                        style: const TextStyle(
                                          color: AppColors.primaryAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          )
                        else
                          const Text(
                            'No badges yet. Connect and have a safe talk!',
                            style: TextStyle(
                              color: Colors.white54,
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Connect Button (only shown for other users)
                  if (!isSelf)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isConnecting || _isRequestSent)
                            ? null
                            : _sendConnectionRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryAccent,
                          foregroundColor: AppColors.background,
                          disabledBackgroundColor: AppColors.primaryAccent
                              .withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _isConnecting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.background,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isRequestSent
                                        ? Icons.how_to_reg_rounded
                                        : Icons.person_add_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isRequestSent
                                        ? 'Request Sent'
                                        : 'Send Connection Request',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
