import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audio_session/audio_session.dart';

class SignalingService {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  late io.Socket socket;
  RTCPeerConnection? peerConnection;
  bool _isInit = false;
  MediaStream? localStream;
  MediaStream? remoteStream;

  final String serverUrl =
      dotenv.env['SIGNALING_SERVER_URL'] ?? 'http://localhost:3000';

  Function(MediaStream stream)? onAddRemoteStream;
  Function(
    String message,
    String partnerId,
    String partnerName,
    String partnerAvatar,
    double partnerRating,
  )?
  onMatchFound;
  Function(
    String message,
    String partnerId,
    String partnerName,
    String partnerAvatar,
    double partnerRating,
  )?
  onMatchFoundMain;
  Function()? onWaitingForMatch;
  Function()? onPartnerLeft;
  Function()? onPartnerConnected;
  Function(String message)? onMatchSkipped;

  // Direct call callbacks
  Function(Map<String, dynamic> data)? onIncomingCall;
  Function(String message)? onCallFailed;
  Function(String message)? onCallDeclined;

  // Connection state monitoring
  Function(RTCPeerConnectionState state)? onConnectionStateChange;

  String? currentRoomId;
  String? partnerId;
  String? partnerName;
  String? partnerAvatar;
  double partnerRating = 0.0;

  final List<RTCIceCandidate> _remoteCandidates = [];
  bool _isRemoteDescriptionSet = false;
  bool _isWebRTCBusy = false; // Prevent race conditions

  // ─── ICE Server Configuration ───
  // Using multiple STUN + free TURN servers for reliability
  static const Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turns:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'sdpSemantics': 'unified-plan',
    'iceCandidatePoolSize': 10,
  };

  // ─── Registration ───
  Future<void> registerUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ Signaling: Cannot register, no user ID found');
      return;
    }
    if (!socket.connected) {
      debugPrint(
        '⚠️ Signaling: Socket not connected, will register on connect',
      );
      return;
    }

    String nickname = user.userMetadata?['nickname'] ?? 'User';
    String avatar = user.userMetadata?['avatar'] ?? '👤';

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('nickname, avatar')
          .eq('id', user.id)
          .single();
      nickname = profile['nickname'] ?? nickname;
      avatar = profile['avatar'] ?? avatar;
    } catch (e) {
      debugPrint('⚠️ Signaling: Could not fetch profile for registration: $e');
    }

    debugPrint('📤 Signaling: Registering user ${user.id}');
    socket.emit('register_user', {
      'userId': user.id,
      'nickname': nickname,
      'avatar': avatar,
    });
  }

  // ─── Socket Connection ───
  void connect() {
    if (_isInit) return;
    _isInit = true;

    socket = io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 5000,
      'timeout': 20000,
    });

    socket.connect();

    socket.onConnect((_) {
      debugPrint('✅ Signaling: Connected. ID: ${socket.id}');
      registerUser();
    });

    socket.onConnectError((data) {
      debugPrint('❌ Signaling: Connection Error: $data');
      if (onCallFailed != null) {
        onCallFailed!('Connection lost. Please check your network.');
      }
    });

    socket.onReconnect((_) {
      debugPrint('🔄 Signaling: Reconnected');
      registerUser();
    });
    socket.onDisconnect((_) {
      debugPrint('⚠️ Signaling: Disconnected');
    });

    // ─── Match Found ───
    socket.on('match_found', (data) async {
      debugPrint('🎯 Match found: $data');
      partnerId = data['partnerId'];
      partnerName = data['partnerName'] ?? 'Someone';
      partnerAvatar = data['partnerAvatar'] ?? '👤';
      partnerRating = (data['partnerRating'] ?? 0.0).toDouble();
      final message = data['message'] ?? '';

      if (onMatchFound != null) {
        onMatchFound!(
          message,
          partnerId!,
          partnerName!,
          partnerAvatar!,
          partnerRating,
        );
      } else if (onMatchFoundMain != null) {
        onMatchFoundMain!(
          message,
          partnerId!,
          partnerName!,
          partnerAvatar!,
          partnerRating,
        );
      }

      currentRoomId = data['roomId'];
      bool isCaller = data['isCaller'] ?? false;

      // Reset WebRTC state for fresh connection
      _remoteCandidates.clear();
      _isRemoteDescriptionSet = false;

      // Enable WakeLock to keep screen alive during call
      try {
        await WakelockPlus.enable();
        debugPrint('🔒 WakeLock enabled');
      } catch (e) {
        debugPrint('WakeLock error: $e');
      }

      await _initWebRTC();

      // Delay creation of offer slightly to ensure tracks are settled
      await Future.delayed(const Duration(milliseconds: 500));

      if (isCaller) {
        debugPrint('📞 Creating offer as caller...');
        final offer = await peerConnection?.createOffer();
        if (offer != null) {
          await peerConnection?.setLocalDescription(offer);
          socket.emit('webrtc_offer', {
            'offer': {'sdp': offer.sdp, 'type': offer.type},
            'roomId': currentRoomId,
          });
          debugPrint('📤 Offer sent');
        }
      } else {
        debugPrint('📞 Waiting for offer as receiver...');
      }
    });

    socket.on('waiting_for_match', (data) {
      debugPrint('⏳ Signaling: Waiting for match...');
      if (onWaitingForMatch != null) onWaitingForMatch!();
    });

    socket.on('rejoined_room', (data) {
      debugPrint('🔄 Signaling: Rejoined active room: ${data['roomId']}');
      currentRoomId = data['roomId'];
    });

    // ─── WebRTC Offer ───
    socket.on('webrtc_offer', (data) async {
      debugPrint('📥 Received WebRTC Offer');
      if (peerConnection == null) {
        debugPrint('⚠️ PeerConnection null, initializing...');
        await _initWebRTC();
      }

      try {
        await peerConnection?.setRemoteDescription(
          RTCSessionDescription(data['offer']['sdp'], data['offer']['type']),
        );
        _isRemoteDescriptionSet = true;
        debugPrint('✅ Remote description set (offer)');
        _processIceCandidateQueue();

        final answer = await peerConnection?.createAnswer();
        if (answer != null) {
          await peerConnection?.setLocalDescription(answer);
          socket.emit('webrtc_answer', {
            'answer': {'sdp': answer.sdp, 'type': answer.type},
            'roomId': currentRoomId,
          });
          debugPrint('📤 Answer sent');
        }
      } catch (e) {
        debugPrint('❌ Error handling offer: $e');
      }
    });

    // ─── WebRTC Answer ───
    socket.on('webrtc_answer', (data) async {
      debugPrint('📥 Received WebRTC Answer');
      try {
        await peerConnection?.setRemoteDescription(
          RTCSessionDescription(data['answer']['sdp'], data['answer']['type']),
        );
        _isRemoteDescriptionSet = true;
        debugPrint('✅ Remote description set (answer)');
        _processIceCandidateQueue();
      } catch (e) {
        debugPrint('❌ Error handling answer: $e');
      }
    });

    // ─── ICE Candidate ───
    socket.on('webrtc_ice_candidate', (data) async {
      debugPrint('📥 Received ICE Candidate');
      if (data['candidate'] == null) return;

      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );

      if (peerConnection != null && _isRemoteDescriptionSet) {
        try {
          await peerConnection?.addCandidate(candidate);
          debugPrint('✅ ICE candidate added immediately');
        } catch (e) {
          debugPrint('❌ Error adding ICE candidate: $e');
        }
      } else {
        _remoteCandidates.add(candidate);
        debugPrint(
          '📋 ICE candidate queued (${_remoteCandidates.length} total)',
        );
      }
    });

    // ─── Partner Left ───
    socket.on('partner_left', (_) {
      debugPrint('👋 Partner left the room');
      if (onPartnerLeft != null) onPartnerLeft!();
      _closeWebRTC();
    });

    // ─── Direct Calling Events ───
    socket.on('incoming_call', (data) {
      debugPrint(
        '📞 Incoming Call: ${data['callerName']} (${data['callerSocketId']})',
      );
      if (onIncomingCall != null) {
        onIncomingCall!(data);
      }
    });

    socket.on('call_failed', (data) {
      if (onCallFailed != null) onCallFailed!(data['message']);
    });

    socket.on('call_declined', (data) {
      if (onCallDeclined != null) onCallDeclined!(data['message']);
    });

    socket.on('partner_connected', (data) {
      debugPrint('🤝 Signaling: Partner connected event received!');
      if (onPartnerConnected != null) {
        onPartnerConnected!();
      } else {
        debugPrint('⚠️ Signaling: onPartnerConnected callback is NOT set yet');
      }
    });

    socket.on('match_skipped', (data) {
      debugPrint('❌ Signaling: Match skipped by partner');
      if (onMatchSkipped != null) onMatchSkipped!('Partner skipped the match.');
    });

    socket.on('partner_left', (data) {
      debugPrint('👋 Signaling: Partner left session');
      if (onPartnerLeft != null) onPartnerLeft!();
      _closeWebRTC();
    });
  }

  // ─── ICE Candidate Queue Processing ───
  void _processIceCandidateQueue() {
    if (_remoteCandidates.isEmpty) return;
    debugPrint(
      '🔄 Processing ${_remoteCandidates.length} queued ICE candidates',
    );
    for (var candidate in _remoteCandidates) {
      peerConnection?.addCandidate(candidate).catchError((e) {
        debugPrint('❌ Error adding queued candidate: $e');
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
  }) {
    debugPrint('📤 Signaling: Finding match for $role on $topic');
    socket.emit('find_match', {
      'role': role,
      'topic': topic,
      'userId': userId,
      'nickname': nickname,
      'avatar': avatar,
      'rating': rating,
    });
  }

  void acceptMatch() {
    debugPrint(
      '📤 Signaling: acceptMatch called. currentRoomId: $currentRoomId',
    );
    if (currentRoomId != null) {
      socket.emit('accept_match', {'roomId': currentRoomId});
    } else {
      debugPrint('🚨 ERROR: acceptMatch called but currentRoomId is null!');
    }
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
  }) async {
    registerUser();
    final callerId = Supabase.instance.client.auth.currentUser?.id;
    if (callerId == null) return;

    String finalName = callerName ?? 'Someone';
    String finalAvatar = callerAvatar ?? '👤';

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
        debugPrint('⚠️ Signaling: Could not fetch profile for call: $e');
      }
    }

    socket.emit('call_direct', {
      'targetUserId': targetUserId,
      'callerId': callerId,
      'callerName': finalName,
      'callerAvatar': finalAvatar,
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
    if (_isWebRTCBusy) {
      debugPrint('⏳ WebRTC init already in progress, waiting...');
      // Wait for current init to finish
      while (_isWebRTCBusy) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }
    _isWebRTCBusy = true;
    debugPrint('🔧 Initializing fresh WebRTC connection...');

    try {
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
      debugPrint('🎵 AudioSession configured for Voice Chat');

      // Clean up any existing connection FIRST
      if (peerConnection != null) {
        debugPrint('🧹 Cleaning up old PeerConnection');
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
      debugPrint('✅ PeerConnection created');

      // Monitor connection state
      peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('🔗 Connection State: $state');
        if (onConnectionStateChange != null) {
          onConnectionStateChange!(state);
        }
      };

      peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint('🧊 ICE Connection State: $state');
      };

      peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
        debugPrint('📡 ICE Gathering State: $state');
      };

      // Handle outgoing ICE candidates
      peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        if (currentRoomId != null) {
          socket.emit('webrtc_ice_candidate', {
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
            'roomId': currentRoomId,
          });
        }
      };

      // Handle incoming remote audio tracks
      peerConnection?.onTrack = (RTCTrackEvent event) {
        debugPrint('🎵 Remote Track received: ${event.track.kind}');
        if (event.streams.isNotEmpty) {
          remoteStream = event.streams.first;

          // Ensure all remote audio tracks are enabled
          for (var track in remoteStream!.getAudioTracks()) {
            track.enabled = true;
            debugPrint('🔊 Remote audio track enabled: ${track.id}');
          }

          // Route to speakerphone for better hearing (earpiece is too quiet)
          if (!kIsWeb) {
            try {
              Helper.setSpeakerphoneOn(true);
              debugPrint('🔊 Speakerphone ON');
            } catch (e) {
              debugPrint('Speaker error: $e');
            }
          }

          if (onAddRemoteStream != null) {
            onAddRemoteStream!(remoteStream!);
          }
        }
      };

      // Get local microphone stream
      debugPrint('🎤 Requesting microphone access...');
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      debugPrint('🎤 Microphone stream acquired: ${localStream?.id}');

      // Add local audio tracks to connection
      if (localStream != null) {
        for (var track in localStream!.getTracks()) {
          await peerConnection?.addTrack(track, localStream!);
          debugPrint(
            '🎤 Added local track: ${track.kind} (enabled: ${track.enabled})',
          );
        }
      }

      debugPrint('✅ WebRTC initialization complete');
    } catch (e) {
      debugPrint('❌ WebRTC init error: $e');
    } finally {
      _isWebRTCBusy = false;
    }
  }

  // ─── Session Management ───
  void leaveSession(String roomId) {
    socket.emit('end_session', {'roomId': roomId});
    _closeWebRTC();
  }

  void muteMic(bool mute) {
    if (localStream != null) {
      for (var track in localStream!.getAudioTracks()) {
        track.enabled = !mute;
        debugPrint('🎤 Mic ${mute ? "muted" : "unmuted"}');
      }
    }
  }

  void disconnect() {
    // Purposefully stubbed. Singleton socket stays alive for incoming calls.
  }

  void _closeWebRTC() {
    debugPrint('🧹 Closing WebRTC...');

    // Stop and dispose local stream
    localStream?.getTracks().forEach((track) {
      track.stop();
    });
    localStream?.dispose();

    // Stop and dispose remote stream
    remoteStream?.getTracks().forEach((track) {
      track.stop();
    });
    remoteStream?.dispose();

    // Close peer connection
    peerConnection?.close();
    peerConnection?.dispose();

    // Reset all state
    peerConnection = null;
    localStream = null;
    remoteStream = null;
    currentRoomId = null;
    _isRemoteDescriptionSet = false;
    _remoteCandidates.clear();
    _isWebRTCBusy = false;

    // Release WakeLock
    try {
      WakelockPlus.disable();
      debugPrint('🔓 WakeLock disabled');
    } catch (e) {
      debugPrint('WakeLock disable error: $e');
    }

    debugPrint('✅ WebRTC closed');
  }
}
