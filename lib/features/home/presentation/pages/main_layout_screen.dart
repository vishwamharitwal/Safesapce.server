import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/home/presentation/pages/role_selection_screen.dart';
import 'package:flutter_application_1/features/community/presentation/pages/thoughts_screen.dart';
import 'package:flutter_application_1/features/chat/presentation/pages/chat_hub_screen.dart';
import 'package:flutter_application_1/features/profile/presentation/pages/profile_screen.dart';
import 'package:flutter_application_1/features/session/data/signaling_service.dart';
import 'package:flutter_application_1/features/session/presentation/pages/active_session_screen.dart';
import 'package:flutter_application_1/features/session/presentation/pages/incoming_call_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  int _unreadCount = 0;
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
          debugPrint('⚠️ Signaling: Busy, ignoring incoming call');
          return;
        }
        _showIncomingCallDialog(data);
      }
    };

    _signalingService.onMatchFoundMain =
        (message, partnerId, partnerName, partnerAvatar, partnerRating) {
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
                ),
              ),
            );
          }
        };

    _setupGlobalMessageNotifier();
    _setupProfileListener();
    _fetchInitialProfile();
  }

  Future<void> _fetchInitialProfile() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('nickname, avatar')
          .eq('id', myId)
          .single();
      if (mounted) {
        setState(() {
          _currentNickname = data['nickname'] ?? _currentNickname;
          _currentAvatar = data['avatar'] ?? _currentAvatar;
        });
      }
    } catch (e) {
      debugPrint('Error fetching initial profile: $e');
    }
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
            debugPrint('👤 Profile Realtime Update: ${payload.newRecord}');
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

  void _setupGlobalMessageNotifier() {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    // Unique channel name to avoid conflict with ChatHubScreen
    // 1. Listen for new messages
    _messageSubscription = Supabase.instance.client
        .channel('main_layout_msg_${myId.substring(0, 8)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final newMsg = payload.newRecord;
            if (newMsg['sender_id'] == myId) return;

            try {
              // Verify the user is a participant in this connection
              final connId = newMsg['connection_id'];
              final connCheck = await Supabase.instance.client
                  .from('connections')
                  .select('id')
                  .or('sender_id.eq.$myId,receiver_id.eq.$myId')
                  .eq('id', connId)
                  .maybeSingle();

              if (connCheck != null && mounted) {
                setState(() {
                  _unreadCount++;
                });

                // Show notification only if user is NOT on the Chat tab
                if (_currentIndex != 2) {
                  final senderProfile = await Supabase.instance.client
                      .from('profiles')
                      .select('nickname, avatar')
                      .eq('id', newMsg['sender_id'])
                      .single();

                  if (mounted) {
                    _showStyledNotification(
                      title: senderProfile['nickname'] ?? 'New Message',
                      subtitle: newMsg['content'] ?? 'Click to view',
                      avatar: senderProfile['avatar'] ?? '💬',
                    );
                  }
                }
              }
            } catch (e) {
              debugPrint(
                '⚠️ Signaling: Error processing message notification: $e',
              );
            }
          },
        )
        .subscribe();

    // 2. Listen for new connection requests
    _connectionSubscription = Supabase.instance.client
        .channel('main_layout_conn_${myId.substring(0, 8)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'connections',
          callback: (payload) async {
            final newConn = payload.newRecord;
            if (newConn['receiver_id'] == myId &&
                newConn['status'] == 'pending') {
              if (mounted) {
                setState(() {
                  _unreadCount++;
                });

                if (_currentIndex != 2) {
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
                    );
                  }
                }
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
  }) {
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
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  setState(() {
                    _currentIndex = 2; // Go to Chat tab
                    _unreadCount = 0;
                  });
                },
                child: Text(
                  'View',
                  style: TextStyle(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageSubscription?.unsubscribe();
    _connectionSubscription?.unsubscribe();
    _profileSubscription?.unsubscribe();
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
      const ChatHubScreen(),
      ProfileScreen(nickname: _currentNickname, avatar: _currentAvatar),
    ];

    return Scaffold(
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
    );
  }
}
