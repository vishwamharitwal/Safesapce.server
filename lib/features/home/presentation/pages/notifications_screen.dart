import 'package:flutter/material.dart';
import 'package:dilse/core/theme/app_colors.dart';
import 'package:dilse/core/widgets/app_shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dilse/features/community/presentation/widgets/comment_sheet.dart';
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _markAllAsRead();
  }

  Future<void> _fetchNotifications() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final data = await Supabase.instance.client
          .from('notifications')
          .select('''
            id, type, content, is_read, created_at, related_id,
            sender:profiles!sender_id(nickname, avatar)
          ''')
          .eq('receiver_id', myId)
          .order('created_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('NOTIFICATION FETCH ERROR: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('receiver_id', myId)
          .eq('is_read', false);
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? AppShimmer.listLoading()
          : _notifications.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: Colors.white12,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final sender = notif['sender'] ?? {};
                    final content = notif['content'] ?? 'someone';
                    final type = notif['type'] ?? 'comment';
                    final isRead = notif['is_read'] ?? true;
                    final createdAtStr = notif['created_at'];

                    String timeString = _getTimeAgo(createdAtStr);

                    return Dismissible(
                      key: Key(notif['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.redAccent,
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      onDismissed: (direction) async {
                        // Optimistically remove from list
                        setState(() {
                          _notifications.removeAt(index);
                        });
                        
                        // Delete from database
                        try {
                          await Supabase.instance.client
                              .from('notifications')
                              .delete()
                              .eq('id', notif['id']);
                        } catch (e) {
                          debugPrint('Error deleting notification: $e');
                        }
                      },
                      child: Material(
                      color: isRead 
                          ? Colors.transparent 
                          : AppColors.primaryAccent.withValues(alpha: 0.1),
                      child: InkWell(
                        onTap: () {
                          if (type == 'comment' && notif['related_id'] != null) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => CommentSheet(thoughtId: notif['related_id']),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.05),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    sender['avatar'] ?? '👤',
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          height: 1.4,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: '${sender['nickname'] ?? 'Someone'} ',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          if (type == 'comment') ...[
                                            TextSpan(
                                              text: content.isNotEmpty ? content : 'commented on your post.',
                                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                                            ),
                                          ] else
                                            const TextSpan(text: 'interacted with your post.'),
                                          TextSpan(
                                            text: '  $timeString',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.5),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border,
              size: 64,
              color: AppColors.primaryAccent,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No notifications yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'When someone interacts with your\nthoughts, you\'ll see it here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
