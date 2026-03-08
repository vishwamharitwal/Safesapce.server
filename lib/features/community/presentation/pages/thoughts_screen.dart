import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/core/utils/word_filter.dart';
import 'package:flutter_application_1/features/profile/presentation/pages/public_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ThoughtsScreen extends StatefulWidget {
  const ThoughtsScreen({super.key});

  @override
  State<ThoughtsScreen> createState() => _ThoughtsScreenState();
}

class _ThoughtsScreenState extends State<ThoughtsScreen> {
  bool _showMyThoughts = false;
  final _supabase = Supabase.instance.client;
  late Stream<List<Map<String, dynamic>>> _thoughtsStream;

  @override
  void initState() {
    super.initState();
    _fetchThoughts();
  }

  void _fetchThoughts() {
    setState(() {
      _thoughtsStream = _supabase
          .from('thoughts')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(100); // Increased limit for busy times
    });
  }

  String _getTimeAgo(String? timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return 'Just now';
    }
  }

  Future<void> _deletePost(String id) async {
    try {
      await _supabase.from('thoughts').delete().eq('id', id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting post: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreatePostSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    'THINK',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 32,
                      letterSpacing: 4.0,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _showCreatePostSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Post',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab toggles (All Thoughts / My Thoughts) and Refresh
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showMyThoughts = false;
                      });
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Thoughts',
                          style: TextStyle(
                            color: !_showMyThoughts
                                ? Colors.white
                                : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (!_showMyThoughts)
                          Container(
                            height: 2,
                            width: 20,
                            color: AppColors.primaryAccent,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showMyThoughts = true;
                      });
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Thoughts',
                          style: TextStyle(
                            color: _showMyThoughts
                                ? Colors.white
                                : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_showMyThoughts)
                          Container(
                            height: 2,
                            width: 20,
                            color: AppColors.primaryAccent,
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _fetchThoughts,
                    icon: const Icon(Icons.refresh, color: Colors.white54),
                    tooltip: 'Refresh feed',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _thoughtsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryAccent,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }

                  final rawData = snapshot.data ?? [];
                  final currentUser = _supabase.auth.currentUser;
                  final now = DateTime.now();

                  // 24 Hour Filter: Hide thoughts older than 24 hours
                  final data = rawData.where((post) {
                    try {
                      final createdAt = DateTime.parse(
                        post['created_at'].toString(),
                      ).toLocal();
                      return now.difference(createdAt).inHours < 24;
                    } catch (_) {
                      return true;
                    }
                  }).toList();

                  final filteredFeed = _showMyThoughts
                      ? data
                            .where((post) => post['user_id'] == currentUser?.id)
                            .toList()
                      : data;

                  if (filteredFeed.isEmpty) {
                    return Center(
                      child: Text(
                        _showMyThoughts
                            ? "You haven't posted any thoughts yet."
                            : "Silence is golden, but thoughts are fresh for only 24h.",
                        style: const TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      _fetchThoughts();
                    },
                    color: AppColors.primaryAccent,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8.0,
                      ),
                      itemCount: filteredFeed.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Container(
                                margin: const EdgeInsets.only(bottom: 24),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryAccent.withValues(
                                        alpha: 0.15,
                                      ),
                                      AppColors.primaryAccent.withValues(
                                        alpha: 0.05,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: AppColors.primaryAccent.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryAccent
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.people_alt_rounded,
                                        color: AppColors.primaryAccent,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'You are not alone',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '847+ people shared their feelings today.',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 800.ms)
                              .slideY(begin: 0.1, end: 0);
                        }

                        final item = filteredFeed[index - 1];
                        final isOwner = item['user_id'] == currentUser?.id;

                        return _ThoughtCard(
                          id: item['id'].toString(),
                          userId: item['user_id']?.toString() ?? '',
                          avatar: item['avatar'] ?? '👤',
                          nickname: item['nickname'] ?? 'Anonymous',
                          time: _getTimeAgo(item['created_at']?.toString()),
                          content: item['content'] ?? '',
                          initialLikes: item['likes'] ?? 0,
                          isOwner: isOwner,
                          onDelete: () => _deletePost(item['id'].toString()),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThoughtCard extends StatefulWidget {
  final String id;
  final String userId;
  final String avatar;
  final String nickname;
  final String time;
  final String content;
  final int initialLikes;
  final bool isOwner;
  final VoidCallback onDelete;

  const _ThoughtCard({
    required this.id,
    required this.userId,
    required this.avatar,
    required this.nickname,
    required this.time,
    required this.content,
    required this.initialLikes,
    required this.isOwner,
    required this.onDelete,
  });

  @override
  State<_ThoughtCard> createState() => _ThoughtCardState();
}

class _ThoughtCardState extends State<_ThoughtCard> {
  late int _likes;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _likes = widget.initialLikes;
  }

  Future<void> _toggleLike() async {
    final previousLiked = _isLiked;

    setState(() {
      _isLiked = !_isLiked;
      _likes += _isLiked ? 1 : -1;
    });

    try {
      final supabase = Supabase.instance.client;
      // Sync the new like count to the backend
      await supabase
          .from('thoughts')
          .update({'likes': _likes})
          .eq('id', widget.id);
    } catch (e) {
      // Revert the state if the API call fails
      if (mounted) {
        setState(() {
          _isLiked = previousLiked;
          _likes += _isLiked ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sync like: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PublicProfileScreen(
                        userId: widget.userId,
                        avatar: widget.avatar,
                        nickname: widget.nickname,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: Text(
                      widget.avatar,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.nickname,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      widget.time,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isOwner)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: widget.onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.content,
            style: const TextStyle(
              color: Colors.white, // Pure white for better visibility
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Likes
              // "Me Too" Reaction - No count visible
              _ActionItem(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                label: _isLiked ? "Main bhi aisa feel karta hoon" : "Me too",
                color: _isLiked ? Colors.white : Colors.white54,
                onTap: _toggleLike,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet();

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final TextEditingController _postController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isPosting = false;

  final List<String> _topics = [
    'Loneliness',
    'Stress',
    'Relationships',
    'Career',
    'Anxiety',
    'Other',
  ];
  String? _selectedTopic;

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _postThought() async {
    final content = _postController.text.trim();
    if (content.isEmpty) return;

    // --- Safety Check: Word Filter ---
    if (WordFilter.hasBadWords(content)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(WordFilter.warningMessage),
          backgroundColor: AppColors.secondaryAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in first')));
      return;
    }

    setState(() => _isPosting = true);

    try {
      // 1. Check Rate Limit (5 posts per 24 hours)
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toUtc()
          .toIso8601String();
      final countResponse = await _supabase
          .from('thoughts')
          .select('id')
          .eq('user_id', user.id)
          .gte('created_at', yesterday);

      if (countResponse.length >= 5) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Daily limit reached! You can only post 5 thoughts per day.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isPosting = false);
        return;
      }

      final metadata = user.userMetadata;
      final nickname = metadata?['nickname'] ?? 'Guest';
      final avatar = metadata?['avatar'] ?? '👤';

      await _supabase.from('thoughts').insert({
        'user_id': user.id,
        'nickname': nickname,
        'avatar': avatar,
        'content': _selectedTopic != null
            ? '[$_selectedTopic] $content'
            : content,
      });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Share a Thought',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _postController,
              maxLines: 5,
              maxLength: 280,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: "What's on your mind? It's safe here.",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: AppColors.cardBackground,
                        value: _selectedTopic,
                        hint: const Text(
                          'Add Tag',
                          style: TextStyle(color: Colors.white54),
                        ),
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white54,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        items: _topics.map((String topic) {
                          return DropdownMenuItem<String>(
                            value: topic,
                            child: Text(topic),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedTopic = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isPosting ? null : _postThought,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.all(16),
                    shape: const CircleBorder(),
                  ),
                  child: _isPosting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.background,
                            ),
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 24),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
