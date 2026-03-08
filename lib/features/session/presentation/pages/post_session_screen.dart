import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class PostSessionScreen extends StatefulWidget {
  final bool isEarlyExit;
  final bool isUserReported;
  final String partnerId;
  final bool isSignificantSession;

  const PostSessionScreen({
    super.key,
    this.isEarlyExit = false,
    this.isUserReported = false,
    required this.partnerId,
    this.isSignificantSession = false,
  });

  @override
  State<PostSessionScreen> createState() => _PostSessionScreenState();
}

class _PostSessionScreenState extends State<PostSessionScreen> {
  int _starRating = 0;
  String? _selectedTag;
  final List<String> _availableTags = [
    'Good Listener',
    'Polite',
    'Empathetic',
    'Helpful',
    'Friendly',
    'Thoughtful',
    'Tech Geek',
    'Funny',
  ];

  // null = no selection, 0 = happy, 1 = neutral, 2 = sad
  int? _feelingIndex;

  bool _isSubmitting = false;
  bool _isConnecting = false;
  bool _isRequestSent = false;

  @override
  void initState() {
    super.initState();
    // Increment count if it was a valid session
    // Increment count if it was a significant session (>=10s) and not a report
    if (widget.isSignificantSession && !widget.isUserReported) {
      _incrementTalksCount();
    }
  }

  Future<void> _incrementTalksCount() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    debugPrint('📊 Attempting to increment talks count for: $userId');
    if (userId == null) return;

    try {
      final response = await client
          .from('profiles')
          .select('total_talks')
          .eq('id', userId)
          .single();

      int currentTalks = response['total_talks'] as int? ?? 0;
      await client
          .from('profiles')
          .update({'total_talks': currentTalks + 1})
          .eq('id', userId)
          .select();

      debugPrint('✅ Total talks updated successfully: ${currentTalks + 1}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primaryAccent,
            content: const Row(
              children: [
                Icon(Icons.stars_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Talk completed! You just made someone feel heard. 🌟',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error incrementing total_talks in DB: $e');
    }
  }

  Future<void> _sendConnectionRequest() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;

      if (currentUser != null) {
        // Upsert logic or insert logic, catching duplicate cases
        await client.from('connections').insert({
          'sender_id': currentUser.id,
          'receiver_id': widget.partnerId,
          'status': 'pending',
        });

        if (mounted) {
          setState(() {
            _isRequestSent = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connection request sent!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send request: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _processReport() async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      final client = Supabase.instance.client;
      // Use RPC to bypass RLS for updating another user's profile
      await client.rpc(
        'report_user',
        params: {'reported_user_id': widget.partnerId},
      );

      if (mounted) {
        Navigator.pop(context); // close the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User has been reported.')),
        );
        // Navigate away after report
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to report user.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitRatingAndFinish() async {
    setState(() => _isSubmitting = true);

    if (_starRating > 0 && !widget.isEarlyExit && !widget.isUserReported) {
      try {
        final client = Supabase.instance.client;
        final myId = client.auth.currentUser?.id;

        if (myId != null && myId != widget.partnerId) {
          await client.from('user_ratings').upsert({
            'rater_id': myId,
            'target_id': widget.partnerId,
            'stars': _starRating,
            'tag_selected': _selectedTag,
          }, onConflict: 'rater_id, target_id');
        }
      } catch (e) {
        debugPrint('Failed to save rating: $e');
      }
    }

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
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
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Text(
                    widget.isUserReported
                        ? 'User Reported'
                        : widget.isEarlyExit
                        ? 'Session ended early'
                        : 'Thank you for sharing!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isUserReported
                        ? 'Thank you for keeping our community safe.'
                        : widget.isEarlyExit
                        ? 'Your partner disconnected from the session.'
                        : 'We hope this helped',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 48),

                  // Trust Rating Card
                  if (!widget.isEarlyExit && !widget.isUserReported)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.cardBackground,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Rate your partner',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return IconButton(
                                icon: Icon(
                                  index < _starRating
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: Colors.amber,
                                  size: 40,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _starRating = index + 1;
                                  });
                                },
                              );
                            }),
                          ),
                          if (_starRating > 0) ...[
                            const SizedBox(height: 32),
                            const Text(
                              'Award a Community Badge',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: _availableTags.map((tag) {
                                final isSelected = _selectedTag == tag;
                                return ChoiceChip(
                                  label: Text(
                                    tag,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.background
                                          : Colors.white70,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.primaryAccent,
                                  backgroundColor: AppColors.cardBackground,
                                  side: BorderSide.none,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedTag = selected ? tag : null;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Do you feel better Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.cardBackground,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Do you feel better?',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _FeedbackButton(
                              icon: Icons.sentiment_satisfied_alt,
                              isSelected: _feelingIndex == 0,
                              activeColor: Colors.blueAccent,
                              onTap: () {
                                setState(() {
                                  _feelingIndex = 0;
                                });
                              },
                            ),
                            const SizedBox(width: 16),
                            _FeedbackButton(
                              icon: Icons.sentiment_neutral,
                              isSelected: _feelingIndex == 1,
                              activeColor: Colors.amber,
                              onTap: () {
                                setState(() {
                                  _feelingIndex = 1;
                                });
                              },
                            ),
                            const SizedBox(width: 16),
                            _FeedbackButton(
                              icon: Icons.sentiment_dissatisfied,
                              isSelected: _feelingIndex == 2,
                              activeColor: Colors.pinkAccent,
                              onTap: () {
                                setState(() {
                                  _feelingIndex = 2;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Hide Extend Session if it was an early exit or reported
                  if (!widget.isEarlyExit && !widget.isUserReported) ...[
                    // Connect Button
                    ElevatedButton(
                      onPressed: (_isConnecting || _isRequestSent)
                          ? null
                          : _sendConnectionRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: AppColors.background,
                        disabledBackgroundColor: AppColors.primaryAccent
                            .withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: _isConnecting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
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
                                ),
                                const SizedBox(width: 8),
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
                    const SizedBox(height: 16),

                    // Extend Session Button
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Session extensions coming soon!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cardBackground,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Extend session',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Done Button
                  _isSubmitting
                      ? const Center(child: CircularProgressIndicator())
                      : OutlinedButton(
                          onPressed: _submitRatingAndFinish,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.cardBackground
                                .withValues(alpha: 0.2),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),

                  const SizedBox(height: 24),

                  if (!widget.isUserReported)
                    // Report TextButton
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppColors.background,
                            title: const Text('Report User'),
                            content: const Text(
                              'Are you sure you want to report this user? This will flag them for review.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondaryAccent,
                                ),
                                onPressed: _isSubmitting
                                    ? null
                                    : _processReport,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Report',
                                        style: TextStyle(color: Colors.white),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.flag_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      label: const Text(
                        'Report User',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _FeedbackButton({
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : AppColors.cardBackground,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: isSelected ? activeColor : AppColors.textSecondary,
            size: 28,
          ),
        ),
      ),
    );
  }
}
