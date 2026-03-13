import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/chat/presentation/pages/chat_room_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key});

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> {
  final _supabase = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _connectionsStream;
  RealtimeChannel? _messagesSubscription;
  final Set<String> _acceptingIds = {};
  final Set<String> _deletingIds = {};
  // Stateful map: connectionId -> unreadCount (updates in real-time)
  final Map<String, int> _unreadCounts = {};

  @override
  void initState() {
    super.initState();
    final currentUserId = _supabase.auth.currentUser?.id;

    if (currentUserId != null) {
      _setupMessagesListener(currentUserId);
      _connectionsStream = _supabase
          .from('connections')
          .stream(primaryKey: ['id'])
          .map(
            (allConnections) => allConnections.where((conn) {
              return conn['sender_id'] == currentUserId ||
                  conn['receiver_id'] == currentUserId;
            }).toList(),
          );
    } else {
      _connectionsStream = const Stream.empty();
    }
  }

  void _setupMessagesListener(String currentUserId) {
    // Use global channel to stay in sync with MainLayoutScreen
    _messagesSubscription = _supabase
        .channel('global_chat_notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            if (!mounted) return;
            final record = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            final connId = record['connection_id']?.toString();
            if (connId == null) return;

            final senderId = record['sender_id']?.toString();
            final myId = _supabase.auth.currentUser?.id;

            final isMe = senderId != null && 
                         myId != null && 
                         senderId.toLowerCase() == myId.toLowerCase();

            if (isMe) {
              // 1. If I am the sender, I've seen the chat/sent a message, so count for me is 0
              setState(() {
                _unreadCounts[connId] = 0;
              });
            } else if (payload.eventType == PostgresChangeEvent.insert) {
              // 2. If it's a new message from someone else, increment
              setState(() {
                _unreadCounts[connId] = (_unreadCounts[connId] ?? 0) + 1;
              });
            } else {
              // 3. For other events (like is_read update), refresh counts
              _refreshUnreadCount(connId, myId ?? currentUserId);
            }
          },
        )
        .subscribe();
  }

  Future<void> _refreshUnreadCount(String connId, String currentUserId) async {
    final count = await _getUnreadCount(connId);
    if (mounted) {
      setState(() {
        _unreadCounts[connId] = count;
      });
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _acceptRequest(String connectionId) async {
    setState(() => _acceptingIds.add(connectionId));
    try {
      await _supabase
          .from('connections')
          .update({'status': 'accepted'})
          .eq('id', connectionId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Error accepting request: $e')));
    } finally {
      if (mounted) setState(() => _acceptingIds.remove(connectionId));
    }
  }

  Future<void> _deleteConnection(String connectionId) async {
    setState(() => _deletingIds.add(connectionId));
    try {
      await _supabase.from('connections').delete().eq('id', connectionId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('Error deleting connection: $e')),
        );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(connectionId));
    }
  }

  Future<Map<String, dynamic>?> _getPartnerProfile(String partnerId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('nickname, avatar')
          .eq('id', partnerId)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Fetch the last message for a connection
  Future<Map<String, dynamic>?> _getLastMessage(String connectionId) async {
    try {
      final connectionIdValue = int.tryParse(connectionId) ?? connectionId;
      final response = await _supabase
          .from('messages')
          .select('content, sender_id, created_at')
          .eq('connection_id', connectionIdValue)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Fetch the unread message count for a connection.
  /// NOTE: 'is_read' column does not exist yet in Supabase.
  /// Counts are tracked via realtime events in [_unreadCounts] map.
  /// Returns 0 — cached value from [_unreadCounts] is used instead.
  bool _hasIsReadColumn = true; // Assume exists until proven otherwise

  Future<int> _getUnreadCount(String connectionId) async {
    if (!_hasIsReadColumn) return _unreadCounts[connectionId] ?? 0;

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return 0;

      final res = await _supabase
          .from('messages')
          .select('id')
          .eq('connection_id', connectionId)
          .neq('sender_id', currentUserId)
          .eq('is_read', false);

      return (res as List).length;
    } catch (e) {
      // If error is related to missing column, stop trying until next app restart
      if (e.toString().contains('is_read') || e.toString().contains('42703')) {
        _hasIsReadColumn = false;
      }
      return _unreadCounts[connectionId] ?? 0;
    }
  }

  Future<int> _getUnreadCountCached(String connectionId) async {
    if (_unreadCounts.containsKey(connectionId)) {
      return _unreadCounts[connectionId]!;
    }
    final count = await _getUnreadCount(connectionId);
    if (mounted) {
      _unreadCounts[connectionId] = count;
    }
    return count;
  }

  /// Format time like "7:32 pm" or "Yesterday"
  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final messageDate = DateTime(dt.year, dt.month, dt.day);

      if (messageDate == today) {
        final hour = dt.hour > 12
            ? dt.hour - 12
            : (dt.hour == 0 ? 12 : dt.hour);
        final amPm = dt.hour >= 12 ? 'PM' : 'AM';
        final min = dt.minute.toString().padLeft(2, '0');
        return '$hour:$min $amPm';
      } else if (messageDate == yesterday) {
        return 'Yesterday';
      } else if (now.difference(dt).inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[dt.weekday - 1];
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _connectionsStream,
      builder: (context, snapshot) {
        int pendingCount = 0;
        final currentUserId = _supabase.auth.currentUser?.id;

        if (snapshot.hasData && currentUserId != null) {
          final data = snapshot.data!;
          pendingCount = data
              .where(
                (c) =>
                    c['status'] == 'pending' &&
                    c['receiver_id'] == currentUserId,
              )
              .length;
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text(
                'Chats',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppColors.cardBackground,
              elevation: 0,
              bottom: TabBar(
                indicatorColor: AppColors.primaryAccent,
                labelColor: AppColors.primaryAccent,
                unselectedLabelColor: AppColors.textSecondary,
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(text: 'Connections'),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Requests'),
                        if (pendingCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              pendingCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildConnectionsTab(snapshot),
                _buildRequestsTab(snapshot),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionsTab(
    AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryAccent),
      );
    }
    if (snapshot.hasError) {
      final errorStr = snapshot.error.toString();
      if (errorStr.contains('timedOut') ||
          errorStr.contains('timeout') ||
          errorStr.contains('RealtimeSubscribeException')) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primaryAccent),
              SizedBox(height: 16),
              Text(
                'Connecting to server...',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Text(
          'Error loading connections: ${snapshot.error}',
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    final data = snapshot.data ?? [];
    final acceptedConnections = data
        .where((c) => c['status'] == 'accepted')
        .toList();

    if (acceptedConnections.isEmpty) {
      return const Center(
        child: Text(
          "You don't have any active connections yet.",
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: acceptedConnections.length,
      itemBuilder: (context, index) {
        final conn = acceptedConnections[index];
        final currentUserId = _supabase.auth.currentUser?.id;
        final partnerId = conn['sender_id'] == currentUserId
            ? conn['receiver_id']
            : conn['sender_id'];
        final connId = conn['id'].toString();

        return FutureBuilder<Map<String, dynamic>?>(
          future: _getPartnerProfile(partnerId),
          builder: (context, profileSnapshot) {
            if (!profileSnapshot.hasData) {
              return const SizedBox(
                height: 84,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnapshot.data!;
            return FutureBuilder<Map<String, dynamic>?>(
              future: _getLastMessage(connId),
              builder: (context, msgSnapshot) {
                return FutureBuilder<int>(
                  future: _getUnreadCountCached(connId),
                  builder: (context, unreadSnapshot) {
                    final lastMsg = msgSnapshot.data;
                    final lastText = lastMsg?['content'] as String? ?? '';
                    final lastTimeFormatted = _formatTime(
                      lastMsg?['created_at'] as String?,
                    );
                    final isFromMe = lastMsg?['sender_id'] == currentUserId;
                    // Use the stateful map for instant real-time updates
                    // UI Override: If I sent the last message, unread count is always 0
                    final unreadCount = isFromMe ? 0 : (_unreadCounts[connId] ?? 0);

                    return _ConnectionItem(
                      connectionId: connId,
                      avatar: profile['avatar'] ?? '👤',
                      name: profile['nickname'] ?? 'Unknown',
                      lastMessage: lastText.isNotEmpty
                          ? (isFromMe ? 'You: $lastText' : lastText)
                          : 'Tap to start chatting',
                      lastTime: lastTimeFormatted,
                      unreadCount: unreadCount,
                      isRequest: false,
                      onTap: () {
                        setState(() {
                          _unreadCounts[connId] = 0;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatRoomScreen(
                              connectionId: connId,
                              avatar: profile['avatar'] ?? '👤',
                              name: profile['nickname'] ?? 'Unknown',
                            ),
                          ),
                        ).then((_) {
                          // Optional: refresh count when returning
                          _refreshUnreadCount(connId, currentUserId ?? '');
                        });
                      },
                      onAccept: () {}, // Not used here
                      onDelete: () => _deleteConnection(connId),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsTab(AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryAccent),
      );
    }
    if (snapshot.hasError) {
      final errorStr = snapshot.error.toString();
      if (errorStr.contains('timedOut') ||
          errorStr.contains('timeout') ||
          errorStr.contains('RealtimeSubscribeException')) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primaryAccent),
              SizedBox(height: 16),
              Text(
                'Connecting to server...',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Text(
          'Error loading requests: ${snapshot.error}',
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    final data = snapshot.data ?? [];
    final currentUserId = _supabase.auth.currentUser?.id;
    final pendingRequests = data
        .where(
          (c) => c['status'] == 'pending' && c['receiver_id'] == currentUserId,
        )
        .toList();

    if (pendingRequests.isEmpty) {
      return const Center(
        child: Text(
          "No pending requests right now.",
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingRequests.length,
      itemBuilder: (context, index) {
        final req = pendingRequests[index];
        final partnerId = req['sender_id'];

        return FutureBuilder<Map<String, dynamic>?>(
          future: _getPartnerProfile(partnerId),
          builder: (context, profileSnapshot) {
            if (!profileSnapshot.hasData) {
              return const SizedBox(
                height: 84,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnapshot.data!;
            return _ConnectionItem(
              connectionId: req['id'].toString(),
              avatar: profile['avatar'] ?? '👤',
              name: profile['nickname'] ?? 'Unknown',
              lastMessage: '',
              lastTime: '',
              unreadCount: 0,
              isRequest: true,
              isLoadingAccept: _acceptingIds.contains(req['id'].toString()),
              isLoadingDelete: _deletingIds.contains(req['id'].toString()),
              onAccept: () => _acceptRequest(req['id'].toString()),
              onDelete: () => _deleteConnection(req['id'].toString()),
            );
          },
        );
      },
    );
  }
}

class _ConnectionItem extends StatelessWidget {
  final String connectionId;
  final String avatar;
  final String name;
  final String lastMessage;
  final String lastTime;
  final int unreadCount;
  final bool isRequest;
  final bool isLoadingAccept;
  final bool isLoadingDelete;
  final VoidCallback onAccept;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const _ConnectionItem({
    required this.connectionId,
    required this.avatar,
    required this.name,
    required this.lastMessage,
    required this.lastTime,
    this.unreadCount = 0,
    this.isRequest = false,
    this.isLoadingAccept = false,
    this.isLoadingDelete = false,
    required this.onAccept,
    required this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemWidget = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: Center(
              child: Text(avatar, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 16),
          // Name + Last Message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isRequest && lastMessage.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          // Right side: Time + Actions
          if (isRequest) ...[
            isLoadingDelete
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
            ElevatedButton(
              onPressed: isLoadingAccept ? null : onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoadingAccept
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.background,
                      ),
                    )
                  : const Text(
                      'Accept',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ] else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (lastTime.isNotEmpty)
                  Text(
                    lastTime,
                    style: TextStyle(
                      color: unreadCount > 0
                          ? AppColors.primaryAccent
                          : Colors.white54,
                      fontSize: 12,
                      fontWeight: unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                const SizedBox(height: 8),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366), // WhatsApp Green
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.2),
                    size: 20,
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    // Wrap in GestureDetector for tap-to-open on connections
    if (!isRequest) {
      final tappableItem = GestureDetector(
        onTap: onTap,
        child: itemWidget,
      );

      return Dismissible(
        key: ValueKey(connectionId),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          child: const Icon(Icons.person_remove_rounded, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.background,
              title: const Text(
                'Disconnect',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                'Are you sure you want to disconnect from $name?',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Disconnect',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
        onDismissed: (direction) {
          onDelete();
        },
        child: tappableItem,
      );
    }

    return itemWidget;
  }
}
