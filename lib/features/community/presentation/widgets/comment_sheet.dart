import 'package:flutter/material.dart';
import 'package:dilse/core/theme/app_colors.dart';
import 'package:dilse/core/utils/profanity_filter.dart';
import 'package:dilse/core/utils/crisis_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dilse/core/widgets/app_shimmer.dart';
import 'package:shimmer/shimmer.dart';
import 'package:dilse/features/profile/presentation/pages/public_profile_screen.dart';

class CommentSheet extends StatefulWidget {
  final String thoughtId;

  const CommentSheet({super.key, required this.thoughtId});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isPosting = false;
  String? _errorMessage;

  // Pagination state
  final ScrollController _scrollController = ScrollController();
  final List<dynamic> _allComments = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadInitialComments();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreComments();
    }
  }

  Future<void> _loadInitialComments() async {
    setState(() {
      _isLoadingMore = true;
      _allComments.clear();
      _currentPage = 0;
      _hasMore = true;
    });

    try {
      final response = await _supabase
          .from('thought_comments')
          .select(
            'id, thought_id, user_id, nickname, avatar, content, created_at',
          )
          .eq('thought_id', widget.thoughtId)
          .order('created_at', ascending: true)
          .range(0, _pageSize - 1);

      if (mounted) {
        setState(() {
          _allComments.addAll(response);
          _hasMore = response.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadMoreComments() async {
    setState(() => _isLoadingMore = true);

    try {
      _currentPage++;
      final from = _currentPage * _pageSize;
      final to = from + _pageSize - 1;

      final response = await _supabase
          .from('thought_comments')
          .select(
            'id, thought_id, user_id, nickname, avatar, content, created_at',
          )
          .eq('thought_id', widget.thoughtId)
          .order('created_at', ascending: true)
          .range(from, to);

      if (mounted) {
        setState(() {
          _allComments.addAll(response);
          _hasMore = response.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

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
      return; // Block comment, show helpline instead
    }

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isPosting = true;
      _errorMessage = null;
    });

    try {
      // toxicity check: Check if user has already posted 5 comments on this thought.
      final existingCount = _allComments
          .where((c) => c['user_id'] == user.id)
          .length;
      if (existingCount >= 5) {
        if (mounted) {
          setState(() {
            _errorMessage =
                'You have reached the limit of 5 comments per thought to keep discussions peaceful.';
            _isPosting = false;
          });
        }
        return;
      }

      final metadata = user.userMetadata;
      final nickname = metadata?['nickname'] ?? 'Guest';
      final avatar = metadata?['avatar'] ?? '👤';

      await _supabase.from('thought_comments').insert({
        'thought_id': widget.thoughtId,
        'user_id': user.id,
        'nickname': nickname,
        'avatar': avatar,
        'content': content,
      });

      _commentController.clear();
      _loadInitialComments(); // Refresh list to show new comment
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not post comment')));
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Container(
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
            ),
          const SizedBox(height: 16),
          Expanded(
            child: _allComments.isEmpty && _isLoadingMore
                ? AppShimmer.listLoading(itemCount: 3)
                : _allComments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No comments yet. Be the first!',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _allComments.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _allComments.length) {
                        return _isLoadingMore
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: AppShimmer.listItemLoading(),
                              )
                            : const SizedBox(height: 100);
                      }
                      final comment = _allComments[index];
                      return CommentItem(
                        comment: comment,
                        onReply: () =>
                            _handleReply(comment['nickname'] ?? 'User'),
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 16,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      autofocus: false,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: Colors.white54),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _isPosting ? null : _postComment,
                  icon: _isPosting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: Shimmer.fromColors(
                            baseColor: AppColors.primaryAccent.withValues(
                              alpha: 0.3,
                            ),
                            highlightColor: AppColors.primaryAccent,
                            child: const Icon(Icons.send_rounded),
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  color: AppColors.primaryAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleReply(String nickname) {
    setState(() {
      _commentController.text = '@$nickname ';
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    });
  }
}

class CommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  final VoidCallback onReply;

  const CommentItem({super.key, required this.comment, required this.onReply});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PublicProfileScreen(
                    userId: comment['user_id']?.toString() ?? '',
                    avatar: comment['avatar'] ?? '👤',
                    nickname: comment['nickname'] ?? 'Guest',
                  ),
                ),
              );
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                comment['avatar'] ?? '👤',
                style: const TextStyle(fontSize: 16),
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
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PublicProfileScreen(
                              userId: comment['user_id']?.toString() ?? '',
                              avatar: comment['avatar'] ?? '👤',
                              nickname: comment['nickname'] ?? 'Guest',
                            ),
                          ),
                        );
                      },
                      child: Text(
                        comment['nickname'] ?? 'Guest',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(comment['created_at']),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment['content'] ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                GestureDetector(
                  onTap: onReply,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 6,
                      bottom: 4,
                      right: 16,
                    ),
                    child: Text(
                      'Reply',
                      style: TextStyle(
                        color: AppColors.primaryAccent.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m';
      if (difference.inHours < 24) return '${difference.inHours}h';
      return '${difference.inDays}d';
    } catch (e) {
      return '';
    }
  }
}
