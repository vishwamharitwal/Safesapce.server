import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:dilse/core/theme/app_colors.dart';
import 'package:dilse/core/utils/profanity_filter.dart';
import 'package:dilse/core/utils/crisis_manager.dart';
import 'package:dilse/features/profile/presentation/pages/public_profile_screen.dart';
import 'package:dilse/features/community/presentation/widgets/comment_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dilse/core/widgets/app_shimmer.dart';

class ThoughtsScreen extends StatefulWidget {
  const ThoughtsScreen({super.key});

  @override
  State<ThoughtsScreen> createState() => _ThoughtsScreenState();
}

class _ThoughtsScreenState extends State<ThoughtsScreen> {
  bool _isLoading = false;
  bool _hasError = false;
  bool _showMyThoughts = false;
  bool _isDisposed = false;
  List<Map<String, dynamic>> _thoughts = [];
  Timer? _pollingTimer;
  RealtimeChannel? _thoughtsSubscription;
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _isDisposed = true;
    _pollingTimer?.cancel();
    _scrollController.dispose();
    if (_thoughtsSubscription != null) {
      _supabase.removeChannel(_thoughtsSubscription!);
    }
    super.dispose();
  }

  // Pagination state
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _fetchThoughts();

    _thoughtsSubscription = _supabase
        .channel('public:thoughts')
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'thoughts',
          callback: (payload) {
            if (mounted) {
              final String deletedId = payload.oldRecord['id'].toString();
              setState(() {
                _thoughts.removeWhere((t) => t['id'].toString() == deletedId);
              });
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'thoughts',
          callback: (payload) {
            if (mounted && !_isDisposed) {
              _fetchThoughts(isSilent: true);
            }
          },
        )
        .subscribe();

    _pollingTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (!_isDisposed) {
        _fetchThoughts(isSilent: true);
      }
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        !_isLoading &&
        _hasMore) {
      _loadMoreThoughts();
    }
  }

  Future<void> _fetchThoughts({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoading = true);
    _currentPage = 0;
    _hasMore = true;

    try {
      final data = await _supabase
          .from('thoughts')
          .select('id, user_id, avatar, nickname, created_at, content, likes')
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);

      if (mounted) {
        setState(() {
          _thoughts = List<Map<String, dynamic>>.from(data);
          _hasMore = data.length == _pageSize;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _loadMoreThoughts() async {
    setState(() => _isLoadingMore = true);

    try {
      _currentPage++;
      final from = _currentPage * _pageSize;
      final to = from + _pageSize - 1;

      final data = await _supabase
          .from('thoughts')
          .select('id, user_id, avatar, nickname, created_at, content, likes')
          .order('created_at', ascending: false)
          .range(from, to);

      if (mounted) {
        setState(() {
          _thoughts.addAll(List<Map<String, dynamic>>.from(data));
          _hasMore = data.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
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
    final deletedPostIndex = _thoughts.indexWhere(
      (t) => t['id'].toString() == id,
    );
    if (deletedPostIndex == -1) return;

    final removedPost = _thoughts[deletedPostIndex];

    // Optimistic UI update: Remove instantly
    setState(() {
      _thoughts.removeAt(deletedPostIndex);
    });

    try {
      await _supabase.from('thoughts').delete().eq('id', id);
    } catch (e) {
      if (mounted) {
        // Revert local state if deletion fails
        setState(() {
          _thoughts.insert(deletedPostIndex, removedPost);
        });
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not delete post. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
      }
    }
  }

  void _showCreatePostSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreatePostSheet(),
    );

    if (result == true && mounted) {
      _fetchThoughts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostSheet,
        backgroundColor: AppColors.primaryAccent,
        foregroundColor: AppColors.background,
        elevation: 4,
        icon: const Icon(Icons.coffee_rounded),
        label: const Text(
          'Spill',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 8.0),
              child: Text(
                'Tea Community',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // Tab toggles (All Thoughts / My Thoughts) and Refresh
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            left: _showMyThoughts
                                ? MediaQuery.of(context).size.width / 2 - 36
                                : 0,
                            right: !_showMyThoughts
                                ? MediaQuery.of(context).size.width / 2 - 36
                                : 0,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      setState(() => _showMyThoughts = false),
                                  child: Center(
                                    child: Text(
                                      'Everyone',
                                      style: TextStyle(
                                        color: !_showMyThoughts
                                            ? Colors.white
                                            : Colors.white54,
                                        fontWeight: !_showMyThoughts
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      setState(() => _showMyThoughts = true),
                                  child: Center(
                                    child: Text(
                                      'Me',
                                      style: TextStyle(
                                        color: _showMyThoughts
                                            ? Colors.white
                                            : Colors.white54,
                                        fontWeight: _showMyThoughts
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _fetchThoughts,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      tooltip: 'Refresh feed',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _isLoading && _thoughts.isEmpty
                  ? AppShimmer.listLoading()
                  : _hasError && _thoughts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            color: Colors.white24,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Network connection error.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            'Please refresh the page.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _fetchThoughts,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryAccent
                                  .withValues(alpha: 0.1),
                              foregroundColor: AppColors.primaryAccent,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final currentUser = _supabase.auth.currentUser;

                        final filteredFeed = _showMyThoughts
                            ? _thoughts
                                  .where(
                                    (post) =>
                                        post['user_id'] == currentUser?.id,
                                  )
                                  .toList()
                            : _thoughts;

                        if (filteredFeed.isEmpty) {
                          return Center(
                            child: Text(
                              _showMyThoughts
                                  ? "You haven't posted any thoughts yet."
                                  : "No thoughts found.",
                              style: const TextStyle(color: Colors.white54),
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            await _fetchThoughts();
                          },
                          color: AppColors.primaryAccent,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 8.0,
                            ),
                            itemCount: filteredFeed.length + (_hasMore ? 2 : 1),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Container(
                                      margin: const EdgeInsets.only(bottom: 24),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.favorite_rounded,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Spill the tea with the world.',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.9,
                                                ),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 800.ms)
                                    .slideY(begin: 0.1, end: 0);
                              }

                              if (_hasMore &&
                                  index == filteredFeed.length + 1) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                  ),
                                  child: AppShimmer.listItemLoading(),
                                );
                              }

                              // Safety check for length error
                              if (index > 0 &&
                                  index - 1 < filteredFeed.length) {
                                final item = filteredFeed[index - 1];
                                final isOwner =
                                    item['user_id'] == currentUser?.id;

                                return _ThoughtCard(
                                  id: item['id'].toString(),
                                  userId: item['user_id']?.toString() ?? '',
                                  avatar: item['avatar'] ?? '👤',
                                  nickname: item['nickname'] ?? 'Anonymous',
                                  time: _getTimeAgo(
                                    item['created_at']?.toString(),
                                  ),
                                  content: item['content'] ?? '',
                                  initialLikes: item['likes'] ?? 0,
                                  isOwner: isOwner,
                                  onDelete: () =>
                                      _deletePost(item['id'].toString()),
                                );
                              }

                              return const SizedBox.shrink();
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
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _likes = widget.initialLikes;
    _checkIsLiked();
  }

  @override
  void didUpdateWidget(covariant _ThoughtCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.initialLikes != widget.initialLikes) {
      if (oldWidget.id != widget.id) {
        _checkIsLiked();
      }
      setState(() {
        _likes = widget.initialLikes;
      });
    }
  }

  Future<void> _checkIsLiked() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('thought_likes')
          .select('id')
          .eq('thought_id', widget.id)
          .eq('user_id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isLiked = data != null;
        });
      }
    } catch (_) {
      // Silently fail if table doesn't exist yet or other issues
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Please login to like')));
      return;
    }

    _isLiking = true;
    final previousLiked = _isLiked;

    setState(() {
      _isLiked = !_isLiked;
      _likes += _isLiked ? 1 : -1;
    });

    HapticFeedback.lightImpact();

    try {
      final supabase = Supabase.instance.client;
      if (_isLiked) {
        await supabase.from('thought_likes').insert({
          'thought_id': widget.id, // Direct string (UUID)
          'user_id': user.id,
        });
      } else {
        await supabase
            .from('thought_likes')
            .delete()
            .eq('thought_id', widget.id) // Direct string (UUID)
            .eq('user_id', user.id);
      }
    } catch (e) {
      // Revert the state if the API call fails
      if (mounted) {
        setState(() {
          _isLiked = previousLiked;
        });
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Failed to sync like: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
      }
    } finally {
      if (mounted) {
        _isLiking = false;
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Text(
                      widget.avatar,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.nickname,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (_likes >= 1) ...[
                          const SizedBox(width: 8),
                          const _HotTeaIndicator(),
                        ],
                      ],
                    ),
                    Text(
                      widget.time,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
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
                  tooltip: 'Delete Post',
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _ActionItem(isLiked: _isLiked, likes: _likes, onTap: _toggleLike),
              const SizedBox(width: 12),
              _CommentButton(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => CommentSheet(thoughtId: widget.id),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final bool isLiked;
  final int likes;
  final VoidCallback onTap;

  const _ActionItem({
    required this.isLiked,
    required this.likes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isLiked
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLiked ? Colors.white : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isLiked ? Colors.white : Colors.white54,
                  size: 18,
                )
                .animate(target: isLiked ? 1 : 0)
                .scaleXY(
                  begin: 1.0,
                  end: 1.2,
                  duration: 150.ms,
                  curve: Curves.easeOutBack,
                )
                .then()
                .scaleXY(begin: 1.2, end: 1.0, duration: 100.ms),
            const SizedBox(width: 8),
            Text(
              "$likes",
              style: TextStyle(
                color: isLiked ? Colors.white : Colors.white54,
                fontSize: 13,
                fontWeight: isLiked ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
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
  String? _errorMessage;

  final List<String> _topics = const [
    'Overthinking',
    'Relationships',
    'Study/Career',
    'Loneliness/Anxiety',
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

    // 🛡️ Security: Enforce maximum post length
    if (content.length > 500) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Post too long. Maximum 500 characters allowed.';
        });
      }
      return;
    }

    // --- Safety Check: Advanced Profanity Filter ---
    final filter = ProfanityFilter();
    final filterError = filter.validate(content);

    if (filterError != null) {
      if (mounted) {
        setState(() {
          _errorMessage = filterError;
        });
      }
      return;
    }

    if (CrisisManager.isCrisis(content)) {
      CrisisManager.showCrisisDialog(context);
      return; // Block post, show helpline instead
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Please log in first';
        });
      }
      return;
    }

    setState(() {
      _isPosting = true;
      _errorMessage = null; // Clear old error
    });

    try {
      // 1. Restore Rate Limit (30 thoughts per 24 hours)
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toUtc()
          .toIso8601String();
      final countResponse = await _supabase
          .from('thoughts')
          .select('id')
          .eq('user_id', user.id)
          .gte('created_at', yesterday);

      if (countResponse.length >= 10) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Daily limit reached! You can only post 10 thoughts per day.',
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
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not post. Please try again.'),
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
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondaryAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.secondaryAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.secondaryAccent,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Spill the Tea',
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
                hintText: "What's the tea? Spill it here.",
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

class _CommentButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CommentButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white54,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text(
              "Comments",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HotTeaIndicator extends StatelessWidget {
  const _HotTeaIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.emoji_food_beverage_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                // Optimized Steam Animation
                Positioned(
                  top: -8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) => 
                      Container(
                        width: 1.5,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ).animate(
                        onPlay: (controller) => controller.repeat(),
                      ).fadeOut(
                        delay: (index * 400).ms,
                        duration: 1000.ms,
                      ).moveY(
                        begin: 0,
                        end: -8,
                        curve: Curves.easeOut,
                      )
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'HOT TEA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
