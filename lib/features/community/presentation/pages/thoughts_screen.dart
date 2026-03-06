import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';

class ThoughtsScreen extends StatefulWidget {
  const ThoughtsScreen({super.key});

  @override
  State<ThoughtsScreen> createState() => _ThoughtsScreenState();
}

class _ThoughtsScreenState extends State<ThoughtsScreen> {
  bool _showMyThoughts = false;

  // Temporary hardcoded feed data. Mutable so users can add to it.
  final List<Map<String, dynamic>> _feedData = [
    {
      'id': '1',
      'avatar': '🦊',
      'nickname': 'SilentFox',
      'time': '2h ago',
      'content':
          'Sometimes the heaviest burden we carry is the one we refuse to talk about. Hoping everyone finds their peace today.',
      'likes': 12,
      'reposts': 2,
      'isOwner': false,
    },
    {
      'id': '2',
      'avatar': '🐼',
      'nickname': 'RestingPanda',
      'time': '5h ago',
      'content':
          'Just wanted to say that if you are reading this, you are doing great. One step at a time.',
      'likes': 45,
      'reposts': 5,
      'isOwner': false,
    },
    {
      'id': '3',
      'avatar': '🐰',
      'nickname': 'LostBunny',
      'time': '1d ago',
      'content':
          'I always feel like I am falling behind everyone else, but I realized today that everyone has their own timeline.',
      'likes': 8,
      'reposts': 1,
      'isOwner': false,
    },
    {
      'id': '4',
      'avatar': '🐯',
      'nickname': 'BraveTiger',
      'time': '1d ago',
      'content':
          'It is okay to not be okay. Took me a long time to accept that.',
      'likes': 102,
      'reposts': 24,
      'isOwner': false,
    },
  ];

  void _deletePost(String id) {
    setState(() {
      _feedData.removeWhere((post) => post['id'] == id);
    });
  }

  void _showCreatePostSheet() {
    final TextEditingController postController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                  controller: postController,
                  maxLines: 5,
                  maxLength: 280,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "What's on your mind? It's safe here.",
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (postController.text.trim().isNotEmpty) {
                      setState(() {
                        _feedData.insert(0, {
                          'id': DateTime.now().millisecondsSinceEpoch
                              .toString(),
                          'avatar': '👤', // Default avatar for current user
                          'nickname': 'You',
                          'time': 'Just now',
                          'content': postController.text.trim(),
                          'likes': 0,
                          'reposts': 0,
                          'isOwner': true,
                        });
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Post Thought',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

            // Tab toggles (All Thoughts / My Thoughts)
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
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                itemCount: _showMyThoughts
                    ? _feedData.where((post) => post['isOwner']).length
                    : _feedData.length,
                itemBuilder: (context, index) {
                  final filteredFeed = _showMyThoughts
                      ? _feedData.where((post) => post['isOwner']).toList()
                      : _feedData;

                  final item = filteredFeed[index];
                  return _ThoughtCard(
                    id: item['id'],
                    avatar: item['avatar'],
                    nickname: item['nickname'],
                    time: item['time'],
                    content: item['content'],
                    initialLikes: item['likes'],
                    initialReposts: item['reposts'],
                    isOwner: item['isOwner'],
                    onDelete: () => _deletePost(item['id']),
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
  final String avatar;
  final String nickname;
  final String time;
  final String content;
  final int initialLikes;
  final int initialReposts;
  final bool isOwner;
  final VoidCallback onDelete;

  const _ThoughtCard({
    required this.id,
    required this.avatar,
    required this.nickname,
    required this.time,
    required this.content,
    required this.initialLikes,
    required this.initialReposts,
    required this.isOwner,
    required this.onDelete,
  });

  @override
  State<_ThoughtCard> createState() => _ThoughtCardState();
}

class _ThoughtCardState extends State<_ThoughtCard> {
  late int _likes;
  late int _reposts;
  bool _isLiked = false;
  bool _isReposted = false;

  @override
  void initState() {
    super.initState();
    _likes = widget.initialLikes;
    _reposts = widget.initialReposts;
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likes += _isLiked ? 1 : -1;
    });
  }

  void _toggleRepost() {
    setState(() {
      _isReposted = !_isReposted;
      _reposts += _isReposted ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
                child: Center(
                  child: Text(
                    widget.avatar,
                    style: const TextStyle(fontSize: 20),
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
                        color: Colors.white.withOpacity(0.4),
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
                )
              else
                Icon(Icons.more_horiz, color: Colors.white.withOpacity(0.5)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Reposts (Retweet style)
              _ActionItem(
                icon: Icons.repeat,
                count: _reposts.toString(),
                color: _isReposted ? Colors.greenAccent : Colors.white54,
                onTap: _toggleRepost,
              ),
              // Likes
              _ActionItem(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                count: _likes.toString(),
                color: _isLiked ? Colors.pinkAccent : Colors.white54,
                onTap: _toggleLike,
              ),
              // Share
              _ActionItem(
                icon: Icons.share_outlined,
                count: '',
                color: Colors.white54,
                onTap: () {
                  // Share action
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
  final IconData icon;
  final String count;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.count,
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
          Icon(icon, color: color, size: 20),
          if (count.isNotEmpty) const SizedBox(width: 6),
          if (count.isNotEmpty)
            Text(
              count,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
