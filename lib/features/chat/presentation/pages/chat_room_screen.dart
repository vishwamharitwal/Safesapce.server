import 'package:flutter/material.dart';
import 'package:dilse/core/theme/app_colors.dart';
import 'package:dilse/features/session/presentation/pages/active_session_screen.dart';
import 'package:dilse/features/session/data/signaling_service.dart';
import 'package:dilse/core/utils/crisis_manager.dart';
import 'package:dilse/core/utils/profanity_filter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:dilse/core/widgets/app_shimmer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ChatRoomScreen extends StatefulWidget {
  final String connectionId;
  final String avatar;
  final String name;

  const ChatRoomScreen({
    super.key,
    required this.connectionId,
    required this.avatar,
    required this.name,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  late final SignalingService _signalingService;
  final List<Map<String, dynamic>> _optimisticMessages = [];

  bool _isTyping = false;
  bool _isCalling = false;
  bool _isConnected = true;
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _signalingService = SignalingService();
    _setupSignaling();
    _checkInitialConnection();
    _setupConnectivityListener();
    _initializeChatStream();

    _messageController.addListener(() {
      final isNotEmpty = _messageController.text.trim().isNotEmpty;
      if (_isTyping != isNotEmpty) {
        setState(() {
          _isTyping = isNotEmpty;
        });
      }
    });
  }

  void _initializeChatStream() {
    // Mark messages as read on entry
    Future.microtask(() {
      _markMessagesAsRead();
    });

    // Generate the stream with type handling for the ID
    final connectionIdValue =
        int.tryParse(widget.connectionId) ?? widget.connectionId;

    _messagesStream = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('connection_id', connectionIdValue)
        .order('created_at', ascending: true);

    // Listen to new messages to mark them as read in real-time
    _messagesSubscription?.cancel();
    _messagesSubscription = _messagesStream.listen(
      (messages) {
        if (mounted) {
          _markMessagesAsRead();
        }
      },
      onError: (error) {
        debugPrint('[ChatRoomScreen] messagesStream error: $error');
      },
    );
  }

  Future<void> _checkInitialConnection() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isConnected =
            !results.contains(ConnectivityResult.none) || results.length > 1;
      });
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (mounted) {
        final currentlyConnected =
            !results.contains(ConnectivityResult.none) || results.length > 1;

        if (currentlyConnected && !_isConnected) {
          // Internet returned!
          setState(() {
            _isConnected = true;
          });
          // Re-initialize stream to force reconnecting if StreamBuilder didn't catch it
          _initializeChatStream();
        } else if (!currentlyConnected && _isConnected) {
          setState(() {
            _isConnected = false;
          });
        }
      }
    });
  }

  Future<void> _markMessagesAsRead() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    final connectionIdValue =
        int.tryParse(widget.connectionId) ?? widget.connectionId;
    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('connection_id', connectionIdValue)
          .neq('sender_id', myId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[ChatRoomScreen] _markMessagesAsRead error: $e');
    }
  }

  void _setupSignaling() {
    _signalingService.connect();

    _signalingService.onMatchFound =
        (
          message,
          partnerId,
          partnerName,
          partnerAvatar,
          partnerRating,
          targetTime,
        ) {
          if (mounted) {
            setState(() => _isCalling = false);
            Navigator.pushReplacement(
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

    _signalingService.onCallFailed = (message) {
      if (mounted) {
        setState(() => _isCalling = false);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    };

    _signalingService.onCallDeclined = (message) {
      if (mounted) {
        setState(() => _isCalling = false);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('Call was declined.')));
      }
    };
  }

  @override
  void dispose() {
    // 🛡️ Cleanup resources
    _connectivitySubscription?.cancel();
    _messagesSubscription?.cancel();

    // Auto-delete my received + read messages when leaving chat
    final myId = _supabase.auth.currentUser?.id;
    if (myId != null) {
      final connectionIdValue =
          int.tryParse(widget.connectionId) ?? widget.connectionId;
      _supabase
          .from('messages')
          .delete()
          .eq('connection_id', connectionIdValue)
          .neq('sender_id', myId)
          .eq('is_read', true);
    }

    _messageController.dispose();
    _scrollController.dispose();
    // Clear handlers to avoid singleton behavior affecting other screens
    _signalingService.onMatchFound = null;
    _signalingService.onCallFailed = null;
    _signalingService.onCallDeclined = null;

    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (!_isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('No internet connection'),
              backgroundColor: Colors.redAccent,
            ),
          );
      }
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // 🛡️ Security: Enforce maximum message length
    if (text.length > 1000) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Message too long. Max 1000 characters.'),
              backgroundColor: Colors.orange,
            ),
          );
      }
      return;
    }

    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    // 🛡️ Profanity Filter
    final filter = ProfanityFilter();
    final filterError = filter.validate(text);
    if (filterError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(filterError),
              backgroundColor: Colors.orange,
            ),
          );
      }
      return;
    }

    // 🛡️ Crisis Detection - block message and show helpline
    if (CrisisManager.isCrisis(text)) {
      CrisisManager.showCrisisDialog(context);
      return;
    }

    _messageController.clear();
    HapticFeedback.lightImpact();

    final tempMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': currentUserId,
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _optimisticMessages.add(tempMsg);
    });

    // Give UI a moment to build optimistic message, then scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          (_scrollController.position.maxScrollExtent + 100).clamp(
            0,
            _scrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      await _supabase.from('messages').insert({
        'connection_id': widget.connectionId,
        'sender_id': currentUserId,
        'content': text,
        'is_read': false,
      });
      // Do nothing, stream will catch up
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _optimisticMessages.remove(tempMsg);
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Disconnect', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to disconnect from ${widget.name}? This will remove them from your connections and delete your chat history.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final name = widget.name;

              try {
                // Delete messages first, then connection
                await _supabase
                    .from('messages')
                    .delete()
                    .eq('connection_id', widget.connectionId);
                await _supabase
                    .from('connections')
                    .delete()
                    .eq('id', widget.connectionId);

                if (mounted) {
                  navigator.pop(); // close dialog
                  navigator.pop(); // go back to chat hub
                  scaffoldMessenger
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(content: Text('Disconnected from $name.')),
                    );
                }
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  scaffoldMessenger
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(content: Text('Failed to disconnect: $e')),
                    );
                }
              }
            },
            child: const Text(
              'Disconnect',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              child: Center(
                child: Text(
                  widget.avatar,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: AppColors.cardBackground,
            onSelected: (value) {
              if (value == 'disconnect') {
                _showDisconnectDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'disconnect',
                child: Row(
                  children: [
                    Icon(
                      Icons.person_remove_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Disconnect',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppColors.primaryAccent.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_delete_outlined,
                  size: 16,
                  color: AppColors.primaryAccent,
                ),
                const SizedBox(width: 8),
                Text(
                  'Messages are deleted when you leave the chat',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // --- Crisis Helpline Banner ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: Colors.redAccent.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.support_agent_rounded,
                  size: 16,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Need help? iCall Helpline: 9152987821',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ------------------------------
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return AppShimmer.chatListLoading();
                }
                if (!_isConnected || snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
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
                            'Please refresh the chat.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              _checkInitialConnection();
                              _initializeChatStream();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryAccent
                                  .withValues(alpha: 0.1),
                              foregroundColor: AppColors.primaryAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final streamMessages = snapshot.data ?? [];

                // Clean up confirmed optimistic messages to prevent memory leak
                _optimisticMessages.removeWhere(
                  (opt) => streamMessages.any(
                    (msg) =>
                        msg['content'] == opt['content'] &&
                        msg['sender_id'] == opt['sender_id'],
                  ),
                );

                // Merge remaining optimistic messages with stream messages
                final List<Map<String, dynamic>> allMessages = List.from(
                  streamMessages,
                );

                for (var opt in _optimisticMessages) {
                  bool existsInStream = streamMessages.any(
                    (msg) =>
                        msg['content'] == opt['content'] &&
                        msg['sender_id'] == opt['sender_id'],
                  );

                  if (!existsInStream) {
                    allMessages.add(opt);
                  }
                }

                // Sort by created_at so they appear in correct order
                allMessages.sort(
                  (a, b) => (a['created_at'] as String).compareTo(
                    b['created_at'] as String,
                  ),
                );

                if (allMessages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Say hi!',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                // Auto scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                final currentUserId = _supabase.auth.currentUser?.id;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: allMessages.length,
                  itemBuilder: (context, index) {
                    final msg = allMessages[index];
                    final isMe = msg['sender_id'] == currentUserId;
                    final messageText = msg['content'] ?? '';

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.primaryAccent
                              : AppColors.cardBackground,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                        ),
                        child: Text(
                          messageText,
                          style: TextStyle(
                            color: isMe ? AppColors.background : Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primaryAccent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isCalling
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.background,
                            ),
                          )
                        : Icon(
                            _isTyping ? Icons.send_rounded : Icons.call_rounded,
                            color: AppColors.background,
                          ),
                    onPressed: _isCalling
                        ? null
                        : _isTyping
                        ? _sendMessage
                        : () {
                            ScaffoldMessenger.of(context)
                              ..clearSnackBars()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Coming soon: This feature is not available yet',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                          },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
