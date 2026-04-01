import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:async';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audio_session/audio_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SignalingService extends Object with WidgetsBindingObserver {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }
  
  // ─── Lifecycle Management ───
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      debugPrint('[Signaling] 🛑 App detached/force closed! Cleaning up...');
      disconnect();
    }
  }

  late io.Socket socket;
  RTCPeerConnection? peerConnection;
  bool _isInit = false;
  MediaStream? localStream;
  MediaStream? remoteStream;
  Timer? _connectionTimer;

  String get serverUrl {
    // Railway production server URL (Verified LIVE)
    return 'https://safesapceserver-production.up.railway.app';
  }

  // 🛡️ Security: Warn if signaling server is not HTTPS in production (release mode)
  void _assertSecureSignaling() {
    if (!kDebugMode && !serverUrl.startsWith('https://')) {
      assert(
        false,
        '⚠️ SECURITY: Signaling server must use HTTPS in production! Current: $serverUrl',
      );
    }
  }

  bool isPartnerConnectedState = false;
  bool isWebRTCConnected = false;

  Function(MediaStream stream)? onAddRemoteStream;
  Function(
    String message,
    String partnerId,
    String partnerName,
    String partnerAvatar,
    double partnerRating,
    int? targetTime,
  )?
  onMatchFound;
  Function(
    String message,
    String partnerId,
    String partnerName,
    String partnerAvatar,
    double partnerRating,
    int? targetTime,
  )?
  onMatchFoundMain;
  Function()? onWaitingForMatch;
  Function()? onPartnerLeft;
  Function(dynamic data)? onPartnerConnected;
  Function(String message)? onMatchSkipped;

  // Direct call callbacks
  Function(Map<String, dynamic> data)? onIncomingCall;
  Function(String message)? onCallFailed;
  Function(String message)? onCallDeclined;
  Function(String message)? onError;

  // Connection state monitoring
  Function(RTCPeerConnectionState state)? onConnectionStateChange;

  String? currentRoomId;
  String? partnerId;
  String? partnerName;
  String? partnerAvatar;
  double partnerRating = 0.0;

  final List<RTCIceCandidate> _remoteCandidates = [];
  bool _isRemoteDescriptionSet = false;
  Future<void>? _webRTCInitFuture; // Prevent race conditions

  // ─── ICE Server Configuration ───
  // STUN servers (free, public) + TURN servers (openrelay free tier)
  // PRODUCTION: Replace TURN creds with server-generated ephemeral tokens
  // by calling your signaling server's /turn-credentials endpoint.
  static const Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turns:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'sdpSemantics': 'unified-plan',
    'iceCandidatePoolSize': 10,
    'iceTransportPolicy': 'all',
  };

  // ─── Registration ───
  Future<void> registerUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('[Signaling] registerUser: no current user');
      return;
    }
    if (!socket.connected) {
      debugPrint('[Signaling] registerUser: socket not connected');
      return;
    }

    String nickname = user.userMetadata?['nickname'] ?? 'User';
    String avatar = user.userMetadata?['avatar'] ?? '';

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('nickname, avatar')
          .eq('id', user.id)
          .single();
      nickname = profile['nickname'] ?? nickname;
      avatar = profile['avatar'] ?? avatar;
    } catch (_) {}

    socket.emit('register_user', {
      'userId': user.id,
      'nickname': nickname,
      'avatar': avatar,
    });
  }

  // ─── JWT Token Helper ───
  /// Returns current Supabase access token, or null if not logged in.
  String? _getAccessToken() {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  // ─── Network Diagnostics ───
  /// Checks if device has network connectivity. Returns error message or null if OK.
  Future<String?> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return 'No internet connection. Please enable WiFi or mobile data.';
    }
    return null;
  }

  /// Resolves the server hostname to verify DNS is working. Returns error message or null if OK.
  Future<String?> _checkDns() async {
    try {
      final uri = Uri.parse(serverUrl);
      final results = await InternetAddress.lookup(
        uri.host,
      ).timeout(const Duration(seconds: 5));
      if (results.isEmpty) {
        return 'DNS lookup failed for ${uri.host}. Try switching to mobile data or changing your DNS to 8.8.8.8.';
      }
      debugPrint('[Signaling] DNS OK: ${uri.host} -> ${results.first.address}');
      return null;
    } on SocketException catch (e) {
      debugPrint('[Signaling] DNS check failed: $e');
      return 'Cannot reach server. Check your internet connection or try mobile data. (DNS error)';
    } on TimeoutException {
      return 'Server lookup timed out. Your network may be blocking this address. Try mobile data.';
    } catch (e) {
      debugPrint('[Signaling] DNS check unexpected error: $e');
      return 'Network error: $e';
    }
  }

  /// Public method to check if server is reachable before connecting.
  /// Returns null if OK, or an error message string.
  Future<String?> checkServerReachable() async {
    final connError = await _checkConnectivity();
    if (connError != null) return connError;
    return _checkDns();
  }

  // ─── Socket Connection ───
  Future<String?> connect() async {
    _assertSecureSignaling(); // 🛡️ Security check
    if (_isInit) return null;
    _isInit = true;

    final token = _getAccessToken();
    if (token == null) {
      debugPrint('[Signaling] ❌ No access token — cannot connect');
      return 'Not logged in. Please sign in again.';
    }

    // Check network connectivity before attempting connection
    final connError = await _checkConnectivity();
    if (connError != null) {
      debugPrint('[Signaling] ❌ Connectivity check failed: $connError');
      _isInit = false;
      if (onCallFailed != null) onCallFailed!(connError);
      return connError;
    }

    // Pre-check DNS resolution (Log Only - Don't Block!)
    final dnsError = await _checkDns();
    if (dnsError != null) {
      debugPrint('[Signaling] ⚠️ Warning: DNS check failed ($dnsError), but attempting connection anyway...');
    }


    debugPrint('[Signaling] Connecting to $serverUrl');
    debugPrint('[Signaling] Token present: ${token.length > 10}');

    debugPrint('🔌 [Signaling] Attempting connection...');
    debugPrint('📍 [Signaling] URL: $serverUrl');

    debugPrint('[Signaling] 🔄 Initializing Socket.IO connection...');
    debugPrint('[Signaling] 📍 Target URL: $serverUrl');

    socket = io.io(
      serverUrl,
      io.OptionBuilder()
        .setTransports(['websocket', 'polling']) // 🚀 Preferred WebSocket with polling fallback
        .setAuth({'token': token})
        .enableAutoConnect()
        .setReconnectionAttempts(15)
        .setReconnectionDelay(2000)
        .setExtraHeaders({'origin': 'https://safesapceserver-production.up.railway.app'})
        .build(),
    );


    // 🕒 Socket-level timeout check
    _connectionTimer?.cancel();
    _connectionTimer = Timer(const Duration(seconds: 30), () {
      if (socket.connected == false) {
        debugPrint('[Signaling] ⚠️ Connection still not established after 30s');
        socket.connect(); // Try to jumpstart
      }
    });

    debugPrint('[Signaling] ⚡ Socket.IO initialized (auto-connect enabled)');

    socket.onConnect((data) {
      _connectionTimer?.cancel();
      debugPrint(
        '[Signaling] ✅ Connected! transport: ${socket.io.engine?.transport?.name ?? 'unknown'}',
      );
      debugPrint('[Signaling] Socket ID: ${socket.id}');
      registerUser();
    });

    socket.onConnectError((data) {
      debugPrint('[Signaling] ❌ Connect error: $data');
      debugPrint(
        '[Signaling] Transport: ${socket.io.engine?.transport?.name ?? 'unknown'}',
      );
      final errStr = data.toString();
      String userMessage;
      if (errStr.contains('SocketException') &&
          errStr.contains('Failed host lookup')) {
        userMessage =
            'Cannot reach server. Check your internet connection or try mobile data.';
      } else if (errStr.contains('Connection refused')) {
        userMessage =
            'Server is temporarily unavailable. Please try again later.';
      } else if (errStr.contains('timed out') ||
          errStr.contains('TimeoutException')) {
        userMessage =
            'Connection timed out. Your network may be slow or blocking the connection.';
      } else {
        userMessage = 'Connection lost. Please check your network.';
      }
      debugPrint('[Signaling] User message: $userMessage');
      if (onCallFailed != null) {
        onCallFailed!(userMessage);
      }
    });

    // 🛡️ On reconnect, refresh token so expired JWTs don't fail auth
    socket.onReconnect((_) {
      debugPrint(
        '[Signaling] 🔄 Reconnected via ${socket.io.engine?.transport?.name ?? 'unknown'}',
      );
      _refreshAuthToken();
      registerUser();
    });

    socket.onReconnectAttempt((attempt) {
      debugPrint('[Signaling] 🔄 Reconnect attempt $attempt/15');
    });

    socket.onReconnectError((err) {
      debugPrint('[Signaling] ❌ Reconnect error: $err');
      final errStr = err.toString();
      if (errStr.contains('SocketException') &&
          errStr.contains('Failed host lookup')) {
        debugPrint(
          '[Signaling] DNS failure during reconnect — device cannot resolve hostname',
        );
      }
    });

    socket.onReconnectFailed((_) {
      debugPrint('[Signaling] ❌ All reconnect attempts failed');
    });

    socket.on('connect_error', (err) {
      debugPrint('[Signaling] ❌ connect_error event: $err');
      // Server rejected connection (e.g. invalid/expired token)
      final errStr = err.toString();
      if (errStr.contains('Unauthorized') || errStr.contains('jwt')) {
        debugPrint('[Signaling] 🔄 Auth error detected — refreshing token');
        _refreshAuthToken();
      }
    });

    socket.onDisconnect((reason) {
      debugPrint('[Signaling] ⚠️ Socket Disconnected: $reason');
      currentRoomId = null;
      _closeWebRTC();
    });

    // ─── Match Found ───
    socket.on('match_found', (data) async {
      debugPrint('[Signaling] 🎯 Match found: $data');
      partnerId = data['partnerId'];
      partnerName = data['partnerName'] ?? 'Someone';
      partnerAvatar = data['partnerAvatar'] ?? '';
      partnerRating = (data['partnerRating'] ?? 0.0).toDouble();
      final message = data['message'] ?? '';

      currentRoomId = data['roomId'];
      debugPrint(
        '[Signaling] Room: $currentRoomId, isCaller: ${data['isCaller']}',
      );

      int? targetTime;
      if (data['targetTime'] != null) {
        targetTime = int.tryParse(data['targetTime'].toString());
      }

      if (onMatchFound != null) {
        onMatchFound!(
          message,
          partnerId!,
          partnerName!,
          partnerAvatar!,
          partnerRating,
          targetTime,
        );
      } else if (onMatchFoundMain != null) {
        onMatchFoundMain!(
          message,
          partnerId!,
          partnerName!,
          partnerAvatar!,
          partnerRating,
          targetTime,
        );
      }

      bool isCaller = data['isCaller'] ?? false;

      // Reset WebRTC state for fresh connection
      _remoteCandidates.clear();
      _isRemoteDescriptionSet = false;

      await _initWebRTC();

      // Delay creation of offer slightly to ensure tracks are settled
      await Future.delayed(const Duration(milliseconds: 500));

      if (isCaller) {
        debugPrint('[WebRTC] Creating offer as caller...');
        final offer = await peerConnection?.createOffer();
        if (offer != null) {
          await peerConnection?.setLocalDescription(offer);
          debugPrint('[WebRTC] Sending offer to room $currentRoomId');
          socket.emit('webrtc_offer', {
            'offer': {'sdp': offer.sdp, 'type': offer.type},
            'roomId': currentRoomId,
          });
        } else {
          debugPrint('[WebRTC] ❌ Failed to create offer');
        }
      } else {
        debugPrint('[WebRTC] Waiting for offer as callee...');
      }
    });

    socket.on('waiting_for_match', (data) {
      if (onWaitingForMatch != null) onWaitingForMatch!();
    });

    socket.on('rejoined_room', (data) {
      currentRoomId = data['roomId'];
    });

    socket.on('resync', (data) async {
      currentRoomId = data['roomId'] ?? currentRoomId;
      if (peerConnection == null) {
        await _initWebRTC();
      }
    });

    // ─── WebRTC Offer ───
    socket.on('webrtc_offer', (data) async {
      debugPrint('[WebRTC] 📥 Received offer');
      if (peerConnection == null) {
        debugPrint('[WebRTC] PeerConnection null — initializing...');
        await _initWebRTC();
      }

      try {
        await peerConnection?.setRemoteDescription(
          RTCSessionDescription(data['offer']['sdp'], data['offer']['type']),
        );
        _isRemoteDescriptionSet = true;
        debugPrint('[WebRTC] Remote description set (offer)');
        _processIceCandidateQueue();

        final answer = await peerConnection?.createAnswer();
        if (answer != null) {
          await peerConnection?.setLocalDescription(answer);
          debugPrint('[WebRTC] Sending answer to room $currentRoomId');
          socket.emit('webrtc_answer', {
            'answer': {'sdp': answer.sdp, 'type': answer.type},
            'roomId': currentRoomId,
          });
        } else {
          debugPrint('[WebRTC] ❌ Failed to create answer');
        }
      } catch (e) {
        debugPrint('[WebRTC] ❌ Error handling offer: $e');
      }
    });

    // ─── WebRTC Answer ───
    socket.on('webrtc_answer', (data) async {
      debugPrint('[WebRTC] 📥 Received answer');
      try {
        await peerConnection?.setRemoteDescription(
          RTCSessionDescription(data['answer']['sdp'], data['answer']['type']),
        );
        _isRemoteDescriptionSet = true;
        debugPrint('[WebRTC] Remote description set (answer)');
        _processIceCandidateQueue();
      } catch (e) {
        debugPrint('[WebRTC] ❌ Error handling answer: $e');
      }
    });

    // ─── ICE Candidate ───
    socket.on('webrtc_ice_candidate', (data) async {
      if (data['candidate'] == null) return;

      debugPrint('[WebRTC] 📥 Received ICE candidate');
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );

      if (peerConnection != null && _isRemoteDescriptionSet) {
        try {
          await peerConnection?.addCandidate(candidate);
        } catch (e) {
          debugPrint('[WebRTC] ❌ Error adding ICE candidate: $e');
        }
      } else {
        debugPrint('[WebRTC] Queueing ICE candidate (remote desc not set yet)');
        _remoteCandidates.add(candidate);
      }
    });

    // ─── Direct Calling Events ───
    socket.on('incoming_call', (data) {
      if (onIncomingCall != null) {
        onIncomingCall!(data);
      }
    });

    socket.on('call_failed', (data) {
      debugPrint('[Signaling] ❌ Call failed: ${data['message']}');
      if (onCallFailed != null) onCallFailed!(data['message']);
    });

    socket.on('call_declined', (data) {
      debugPrint('[Signaling] Call declined: ${data['message']}');
      if (onCallDeclined != null) onCallDeclined!(data['message']);
    });

    socket.on('partner_connected', (data) {
      isPartnerConnectedState = true;

      // Fallback: If listener missed match_found but got connected, fill missing data
      if (data != null && data is Map) {
        if (data['partnerId'] != null) {
          partnerId = data['partnerId'];
          partnerName = data['partnerName'] ?? 'Someone';
          partnerAvatar = data['partnerAvatar'] ?? '';
          partnerRating = (data['partnerRating'] ?? 0.0).toDouble();
        }
      }

      if (onPartnerConnected != null) {
        onPartnerConnected!(
          data,
        ); // We'll need to update the callback signature
      } else {}
    });

    socket.on('match_skipped', (data) {
      if (onMatchSkipped != null) onMatchSkipped!('Partner skipped the match.');
    });

    socket.on('partner_left', (data) {
      if (onPartnerLeft != null) onPartnerLeft!();
      currentRoomId = null;
      _closeWebRTC();
    });

    return null;
  }

  // ─── Auth Token Refresh ───
  /// Tries to refresh the Supabase session and updates the socket auth token.
  /// Call this when reconnecting or when server returns 401.
  Future<void> _refreshAuthToken() async {
    try {
      debugPrint('[Signaling] 🔄 Refreshing auth token...');
      await Supabase.instance.client.auth.refreshSession();
      final newToken = _getAccessToken();
      if (newToken != null && socket.connected) {
        // Update the auth token for future reconnects
        socket.auth = {'token': newToken};
        debugPrint('[Signaling] ✅ Auth token refreshed');
      } else {
        debugPrint(
          '[Signaling] ⚠️ Token refresh: newToken=${newToken != null}, connected=${socket.connected}',
        );
      }
    } catch (e) {
      debugPrint('[Signaling] ❌ Token refresh failed: $e');
    }
  }

  // ─── Connection Utilities ───
  Future<bool> waitForConnection({int timeoutMs = 10000}) async {
    if (socket.connected) return true;
    debugPrint(
      '[Signaling] Waiting for connection (timeout: ${timeoutMs}ms)...',
    );
    int waited = 0;
    while (!socket.connected && waited < timeoutMs) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited += 100;
      if (socket.connected) {
        debugPrint('[Signaling] Connected after ${waited}ms');
        return true;
      }
    }
    debugPrint('[Signaling] ❌ Connection wait timed out after ${waited}ms');
    return socket.connected;
  }

  // ─── ICE Candidate Queue Processing ───
  void _processIceCandidateQueue() {
    if (_remoteCandidates.isEmpty) return;
    debugPrint(
      '[WebRTC] Processing ${_remoteCandidates.length} queued ICE candidates',
    );
    for (var candidate in _remoteCandidates) {
      peerConnection?.addCandidate(candidate).catchError((e) {
        debugPrint('[WebRTC] ❌ Error adding queued ICE candidate: $e');
      });
    }
    _remoteCandidates.clear();
  }

  // ─── Matchmaking ───
  void findMatch(
    String role,
    String topic,
    String userId, {
    String? nickname,
    String? avatar,
    double? rating,
    int? targetTime,
  }) {
    isPartnerConnectedState = false;
    socket.emit('find_match', {
      'role': role,
      'topic': topic,
      'userId': userId,
      'nickname': nickname,
      'avatar': avatar,
      'rating': rating,
      'targetTime': targetTime,
    });
  }

  void acceptMatch() {
    if (currentRoomId != null) {
      socket.emit('accept_match', {'roomId': currentRoomId});
    } else {}
  }

  void skipMatch() {
    if (currentRoomId != null) {
      socket.emit('skip_match', {'roomId': currentRoomId});
      currentRoomId = null;
    }
  }

  void cancelMatchmaking() {
    socket.emit('cancel_matchmaking');
  }

  // ─── Direct Call ───
  Future<void> callDirect({
    required String targetUserId,
    String? callerName,
    String? callerAvatar,
    int? targetTime,
  }) async {
    registerUser();
    final callerId = Supabase.instance.client.auth.currentUser?.id;
    if (callerId == null) {
      debugPrint('[Signaling] callDirect: no current user');
      return;
    }

    String finalName = callerName ?? 'Someone';
    String finalAvatar = callerAvatar ?? '';

    // If name/avatar not provided, fetch from DB
    if (callerName == null || callerAvatar == null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('nickname, avatar')
            .eq('id', callerId)
            .single();
        finalName = profile['nickname'] ?? finalName;
        finalAvatar = profile['avatar'] ?? finalAvatar;
      } catch (e) {
        debugPrint('[Signaling] ⚠️ Failed to fetch profile for call: $e');
      }
    }

    debugPrint('[Signaling] Calling $targetUserId directly...');
    socket.emit('call_direct', {
      'targetId':
          targetUserId, // Wait, I should make sure this is targetUserId or targetId
      'callerId': callerId,
      'callerName': finalName,
      'callerAvatar': finalAvatar,
      'targetTime': targetTime,
    });
  }

  void acceptCall(String callerSocketId) {
    final receiverUserId = Supabase.instance.client.auth.currentUser?.id;
    socket.emit('accept_call', {
      'callerSocketId': callerSocketId,
      'receiverUserId': receiverUserId,
    });
  }

  void declineCall(String callerSocketId) {
    socket.emit('decline_call', {'callerSocketId': callerSocketId});
  }

  // ─── WebRTC Initialization (FRESH every call) ───
  Future<void> _initWebRTC() async {
    if (_webRTCInitFuture != null) {
      await _webRTCInitFuture;
      return;
    }

    final completer = Completer<void>();
    _webRTCInitFuture = completer.future;

    try {
      debugPrint('[WebRTC] Initializing peer connection...');
      // Configure audio session for background calling
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );
      await session.setActive(true);

      // Clean up any existing connection FIRST
      if (peerConnection != null) {
        await peerConnection?.close();
        peerConnection = null;
      }
      if (localStream != null) {
        localStream?.getTracks().forEach((track) => track.stop());
        await localStream?.dispose();
        localStream = null;
      }
      if (remoteStream != null) {
        remoteStream?.getTracks().forEach((track) => track.stop());
        await remoteStream?.dispose();
        remoteStream = null;
      }

      // Create fresh PeerConnection
      peerConnection = await createPeerConnection(_rtcConfig);
      debugPrint('[WebRTC] ✅ PeerConnection created');

      // Monitor connection state
      peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('[WebRTC] Connection state: $state');

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          isWebRTCConnected = true;
          debugPrint('[WebRTC] ✅ Peer connection established!');
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          isWebRTCConnected = false;
          debugPrint('[WebRTC] ❌ Peer connection lost: $state');
          
          if (currentRoomId != null) {
            debugPrint('[WebRTC] ⚠️ Triggering auto-cleanup for room $currentRoomId');
            if (onPartnerLeft != null) onPartnerLeft!();
            _closeWebRTC();
          }
        }

        if (onConnectionStateChange != null) {
          onConnectionStateChange!(state);
        }
      };

      peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint('[WebRTC] ICE connection state: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          debugPrint(
            '[WebRTC] ❌ ICE connection FAILED — TURN may be unreachable',
          );
        } else if (state ==
            RTCIceConnectionState.RTCIceConnectionStateConnected) {
          debugPrint('[WebRTC] ✅ ICE connection established');
        }
      };

      peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
        debugPrint('[WebRTC] ICE gathering state: $state');
      };

      // Handle outgoing ICE candidates
      peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        if (currentRoomId != null) {
          debugPrint(
            '[WebRTC] Sending ICE candidate: ${candidate.candidate?.substring(0, 60)}...',
          );
          socket.emit('webrtc_ice_candidate', {
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
            'roomId': currentRoomId,
          });
        } else {
          debugPrint('[WebRTC] ⚠️ ICE candidate generated but no roomId');
        }
      };

      // Handle incoming remote audio tracks
      peerConnection?.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          remoteStream = event.streams.first;

          // Ensure all remote audio tracks are enabled
          for (var track in remoteStream!.getAudioTracks()) {
            track.enabled = true;
          }

          // Route to speakerphone for better hearing (earpiece is too quiet)
          // Removed manual speakerphone override to fix local echo tests
          // Wait for earpiece proximity logic to handle properly

          if (onAddRemoteStream != null) {
            onAddRemoteStream!(remoteStream!);
          }
        }
      };

      // Get local microphone stream
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      debugPrint(
        '[WebRTC] ✅ Local audio stream acquired, tracks: ${localStream?.getTracks().length ?? 0}',
      );

      // Add local audio tracks to connection
      if (localStream != null) {
        for (var track in localStream!.getTracks()) {
          await peerConnection?.addTrack(track, localStream!);
        }
      }
    } catch (e) {
      debugPrint('[WebRTC] ❌ Init error: $e');
    } finally {
      if (!completer.isCompleted) completer.complete();
      _webRTCInitFuture = null;
    }
  }

  // ─── Session Management ───
  Future<void> leaveSession(String roomId) async {
    socket.emit('end_session', {'roomId': roomId});
    await _closeWebRTC();
  }

  void muteMic(bool mute) {
    if (localStream != null) {
      for (var track in localStream!.getAudioTracks()) {
        track.enabled = !mute;
      }
    }
  }

  void clearCallbacks() {
    onAddRemoteStream = null;
    onMatchFound = null;
    onMatchFoundMain = null;
    onWaitingForMatch = null;
    onPartnerLeft = null;
    onPartnerConnected = null;
    onMatchSkipped = null;
    onIncomingCall = null;
    onCallFailed = null;
    onCallDeclined = null;
    onError = null;
    onConnectionStateChange = null;
  }

  Future<void> disconnect() async {
    clearCallbacks();
    await _closeWebRTC();
    if (socket.connected) {
      socket.disconnect();
    }
    _isInit = false;
  }

  Future<void> _closeWebRTC() async {
    try {
      // Stop and dispose local stream
      if (localStream != null) {
        for (var track in localStream!.getTracks()) {
          try {
            await track.stop();
          } catch (e) {
            debugPrint('[WebRTC] ⚠️ Error stopping local track: $e');
          }
        }
        try {
          await localStream!.dispose();
        } catch (e) {
          debugPrint('[WebRTC] ⚠️ Error disposing local stream: $e');
        }
      }

      // Stop and dispose remote stream
      if (remoteStream != null) {
        for (var track in remoteStream!.getTracks()) {
          try {
            await track.stop();
          } catch (e) {
            debugPrint('[WebRTC] ⚠️ Error stopping remote track: $e');
          }
        }
        try {
          await remoteStream!.dispose();
        } catch (e) {
          debugPrint('[WebRTC] ⚠️ Error disposing remote stream: $e');
        }
      }

      // Close peer connection
      if (peerConnection != null) {
        try {
          await peerConnection!.close();
          await peerConnection!.dispose();
        } catch (e) {
          debugPrint('[WebRTC] ⚠️ Error disposing peerConnection: $e');
        }
      }
    } catch (globalError) {
      debugPrint('[WebRTC] ❌ Global cleanup error: $globalError');
    } finally {
      // Reset all state
      peerConnection = null;
      localStream = null;
      remoteStream = null;
      currentRoomId = null;
      _isRemoteDescriptionSet = false;
      _remoteCandidates.clear();
      _webRTCInitFuture = null;

      isPartnerConnectedState = false;
      isWebRTCConnected = false;
    }

    // Deactivate audio session to restore normal phone behavior
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      debugPrint('[Audio] ⚠️ Error deactivating audio session: $e');
    }
  }
}
