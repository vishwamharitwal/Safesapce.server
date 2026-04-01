import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dilse/core/theme/app_colors.dart';
import 'package:dilse/features/home/presentation/pages/role_selection_screen.dart';
import 'package:dilse/features/community/presentation/pages/thoughts_screen.dart';
import 'package:dilse/features/chat/presentation/pages/chat_hub_screen.dart';
import 'package:dilse/features/profile/presentation/pages/profile_screen.dart';
import 'package:dilse/features/session/data/signaling_service.dart';
import 'package:dilse/features/session/presentation/pages/active_session_screen.dart';
import 'package:dilse/features/session/presentation/pages/incoming_call_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dilse/features/auth/presentation/pages/login_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MainLayoutScreen extends StatefulWidget {
  final String nickname;
  final String avatar;

  const MainLayoutScreen({
    super.key,
    required this.nickname,
    required this.avatar,
  });

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;
  late final SignalingService _signalingService;
  RealtimeChannel? _messageSubscription;
  RealtimeChannel? _connectionSubscription;
  RealtimeChannel? _profileSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  int _unreadCount = 0;
  Timer? _unreadDebounce;
  String? _pendingChatConnectionId;
  bool _isPendingRequest = false;
  late String _currentNickname;
  late String _currentAvatar;

  @override
  void initState() {
    super.initState();
    _currentNickname = widget.nickname;
    _currentAvatar = widget.avatar;
    _signalingService = SignalingService();
    _signalingService.connect();

    _signalingService.onIncomingCall = (data) {
      if (mounted) {
        // Prevent showing multiple call screens if already in a session or busy
        if (_signalingService.currentRoomId != null) {
          return;
        }
        _showIncomingCallDialog(data);
      }
    };

    _signalingService.onMatchFoundMain =
        (
          message,
          partnerId,
          partnerName,
          partnerAvatar,
          partnerRating,
          targetTime,
        ) {
          if (mounted) {
            // Navigate to active session
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ActiveSessionScreen(
                  signalingService: _signalingService,
                  partnerId: partnerId,
                  partnerName: partnerName,
                  partnerAvatar: partnerAvatar,
                  targetTime: targetTime,
                ),
              ),
            );
          }
        };

    _setupGlobalMessageNotifier();
    _setupConnectionNotifier();
    _setupProfileListener();
    _fetchInitialProfile();
    _fetchInitialUnreadCount();
    _setupConnectivityListener();
    _performDatabaseCleanup(); // 🧹 Start auto-cleanup on launch
  }

  Future<void> _performDatabaseCleanup() async {
    final supabase = Supabase.instance.client;
    final now = DateTime.now();
    final threshold = now.subtract(const Duration(hours: 24)).toIso8601String();

    try {
      // 1. Delete notifications older than 24 hours
      await supabase
          .from('notifications')
          .delete()
          .lt('created_at', threshold);

      // 2. Cleanup orphaned comments 
      // First get IDs of comments that have thoughts
      final activeThoughts = await supabase.from('thoughts').select('id');
      final activeIds = (activeThoughts as List).map((t) => t['id']).toList();
      
      if (activeIds.isNotEmpty) {
        // Delete comments where thought_id is NOT in the active list
        await supabase.from('comments').delete().not('thought_id', 'in', activeIds);
      }
      
      debugPrint('🧹 SafeSpace: Cleanup completed successfully');
    } catch (e) {
      debugPrint('⚠️ SafeSpace: Cleanup failed: $e');
    }
  }

  Future<void> _fetchInitialUnreadCount() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      // Only fetch unread messages for chat badge (pending requests shown separately in ChatHubScreen)
      final messagesRes = await Supabase.instance.client
          .from('messages')
          .select('id')
          .neq('sender_id', myId)
          .eq('is_read', false);
      final int unreadMessagesCount = (messagesRes as List).length;

      if (mounted) {
        setState(() {
          _unreadCount = unreadMessagesCount;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchInitialProfile() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('nickname, avatar, banned_until')
          .eq('id', myId)
          .single();

      if (mounted) {
        // Check for active ban
        if (data['banned_until'] != null) {
          final banUntil = DateTime.parse(data['banned_until']);
          if (banUntil.isAfter(DateTime.now().toUtc())) {
            _showBanDialog(banUntil);
            return;
          }
        }

        setState(() {
          _currentNickname = data['nickname'] ?? _currentNickname;
          _currentAvatar = data['avatar'] ?? _currentAvatar;
        });
      }
    } catch (_) {}
  }

  void _showBanDialog(DateTime banUntil) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text(
          'Account Restricted',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          'Your account has been restricted until ${banUntil.toLocal().toString().split('.')[0]}.\n\nPlease follow community guidelines.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await Supabase.instance.client.auth.signOut();
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _setupProfileListener() {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    _profileSubscription = Supabase.instance.client
        .channel('public:profiles:$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: myId,
          ),
          callback: (payload) {
            final newData = payload.newRecord;
            if (mounted) {
              setState(() {
                _currentNickname = newData['nickname'] ?? _currentNickname;
                _currentAvatar = newData['avatar'] ?? _currentAvatar;
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _setupGlobalMessageNotifier() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    // Unique channel name to avoid conflict with ChatHubScreen
    _messageSubscription = Supabase.instance.client
        .channel('global_chat_notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent
              .insert, // Only listen for NEW messages for notification logic
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            if (!mounted) return;

            final record = payload.newRecord;
            final eventType = payload.eventType;

            if (eventType == PostgresChangeEvent.insert) {
              final senderId = record['sender_id'] as String?;
              final messageId = record['id'] as String?;

              if (senderId != null &&
                  messageId != null &&
                  senderId.toLowerCase() != myId.toLowerCase()) {
                // Verify against database to be 100% sure status is unread and recent
                try {
                  final dbRecord = await Supabase.instance.client
                      .from('messages')
                      .select('id, is_read, created_at, content, connection_id')
                      .eq('id', messageId)
                      .maybeSingle();

                  if (dbRecord != null) {
                    final isRead = dbRecord['is_read'] as bool? ?? true;
                    final createdAt = dbRecord['created_at'] as String?;

                    if (!isRead && createdAt != null) {
                      final msgTime = DateTime.tryParse(createdAt);
                      final window = DateTime.now().toUtc().subtract(
                        const Duration(seconds: 30),
                      );

                      if (msgTime != null && msgTime.toUtc().isAfter(window)) {
                        final connId = dbRecord['connection_id']?.toString();
                        if (_currentIndex != 2) {
                          _showNewMessageNotification(
                            senderId,
                            dbRecord['content'],
                            connId,
                          );
                        }
                      }
                    }
                  }
                } catch (_) {
                  // If fetch fails, fall back to payload record for safety but with strict time check
                  final createdAt = record['created_at'] as String?;
                  final isRead = record['is_read'] as bool? ?? true;

                  if (createdAt != null && !isRead) {
                    final msgTime = DateTime.tryParse(createdAt);
                    final window = DateTime.now().toUtc().subtract(
                      const Duration(seconds: 30),
                    );

                    if (msgTime != null && msgTime.toUtc().isAfter(window)) {
                      final connId = record['connection_id']?.toString();
                      if (_currentIndex != 2) {
                        _showNewMessageNotification(
                          senderId,
                          record['content'],
                          connId,
                        );
                      }
                    }
                  }
                }
              }
            } else if (eventType == PostgresChangeEvent.update) {
              // Debounce absolute count re-fetching to handle rapid changes (Issue #3)
              _unreadDebounce?.cancel();
              _unreadDebounce = Timer(const Duration(milliseconds: 500), () {
                if (mounted) _fetchInitialUnreadCount();
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _showNewMessageNotification(
    String senderId,
    String? content,
    String? connectionId,
  ) async {
    try {
      final senderProfile = await Supabase.instance.client
          .from('profiles')
          .select('nickname, avatar')
          .eq('id', senderId)
          .single();

      if (mounted) {
        _showStyledNotification(
          title: senderProfile['nickname'] ?? 'New Message',
          subtitle: content ?? 'Click to view',
          avatar: senderProfile['avatar'] ?? '💬',
          connectionId: connectionId,
        );
      }
    } catch (_) {}
  }

  void _setupConnectionNotifier() {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    final connectionStartTime = DateTime.now().toUtc();

    // Listen for new connection requests
    _connectionSubscription = Supabase.instance.client
        .channel('global_connection_notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'connections',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: myId,
          ),
          callback: (payload) async {
            if (!mounted) return;

            // Always refresh absolute count on any change (insert/update/delete)
            _fetchInitialUnreadCount();

            // Notify for new INCOMING requests only
            if (payload.eventType == PostgresChangeEvent.insert) {
              final newConn = payload.newRecord;
              if (newConn['receiver_id'] == myId &&
                  newConn['status'] == 'pending' &&
                  _currentIndex != 2) {
                // Skip old replayed connection requests
                final createdAt = newConn['created_at'] as String?;
                if (createdAt != null) {
                  final connTime = DateTime.tryParse(createdAt);
                  if (connTime != null &&
                      connTime.toUtc().isBefore(connectionStartTime)) {
                    return;
                  }
                }

                try {
                  final senderProfile = await Supabase.instance.client
                      .from('profiles')
                      .select('nickname, avatar')
                      .eq('id', newConn['sender_id'])
                      .single();

                  if (mounted) {
                    _showStyledNotification(
                      title: 'New Connection Request',
                      subtitle:
                          '${senderProfile['nickname']} wants to connect!',
                      avatar: senderProfile['avatar'] ?? '👤',
                      connectionId: newConn['id'].toString(),
                      isRequest: true,
                    );
                  }
                } catch (_) {}
              }
            }
          },
        )
        .subscribe();
  }

  void _showStyledNotification({
    required String title,
    required String subtitle,
    required String avatar,
    String? connectionId,
    bool isRequest = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppColors.primaryAccent.withValues(alpha: 0.1),
            ),
          ),
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              setState(() {
                _currentIndex = 2; // Go to Chat tab
                _unreadCount = 0;
                _pendingChatConnectionId = connectionId;
                _isPendingRequest = isRequest;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2D2D2D),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(avatar, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'View',
                  style: TextStyle(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final hasConnection =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (hasConnection && mounted) {
        debugPrint('[MainLayout] Network restored — reconnecting signaling...');
        _signalingService.disconnect();
        _signalingService.connect();
      } else if (mounted) {
        debugPrint('[MainLayout] Network lost');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Please check your network.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _signalingService.onIncomingCall = null;
    _signalingService.onMatchFoundMain = null;
    _messageSubscription?.unsubscribe();
    _connectionSubscription?.unsubscribe();
    _profileSubscription?.unsubscribe();
    _connectivitySubscription?.cancel();
    _unreadDebounce?.cancel();
    _signalingService.disconnect();
    super.dispose();
  }

  void _showIncomingCallDialog(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callData: data,
          signalingService: _signalingService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      RoleSelectionScreen(
        nickname: _currentNickname,
        avatar: _currentAvatar,
        onProfileTap: () {
          setState(() {
            _currentIndex = 3;
          });
        },
      ),
      const ThoughtsScreen(),
      ChatHubScreen(
        initialConnectionId: _pendingChatConnectionId,
        isRequest: _isPendingRequest,
        onClearInitialConnection: () {
          setState(() {
            _pendingChatConnectionId = null;
            _isPendingRequest = false;
          });
        },
      ),
      ProfileScreen(nickname: _currentNickname, avatar: _currentAvatar),
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, dynamic result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        body: screens[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: BottomNavigationBar(
              backgroundColor: AppColors.background,
              currentIndex: _currentIndex,
              onTap: (index) {
                _signalingService.registerUser();
                setState(() {
                  _currentIndex = index;
                  if (index == 2) {
                    _unreadCount = 0;
                  }
                });
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.primaryAccent,
              unselectedItemColor: Colors.white.withValues(alpha: 0.2),
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              elevation: 0,
              items: [
                const BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4.0),
                    child: Icon(Icons.home_outlined),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4.0),
                    child: Icon(Icons.home_rounded),
                  ),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4.0),
                    child: Icon(Icons.forum_outlined),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4.0),
                    child: Icon(Icons.forum_rounded),
                  ),
                  label: 'Think',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Badge(
                      label: _unreadCount > 0 ? Text('$_unreadCount') : null,
                      isLabelVisible: _unreadCount > 0,
                      backgroundColor: Colors.redAccent, // Explicit red dot
                      child: const Icon(Icons.chat_bubble_outline_rounded),
                    ),
                  ),
                  activeIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Badge(
                      label: _unreadCount > 0 ? Text('$_unreadCount') : null,
                      isLabelVisible: _unreadCount > 0,
                      backgroundColor: Colors.redAccent, // Explicit red dot
                      child: const Icon(Icons.chat_bubble_rounded),
                    ),
                  ),
                  label: 'Chat',
                ),
                const BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4.0),
                    child: Icon(Icons.person_outline),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4.0),
                    child: Icon(Icons.person_rounded),
                  ),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
