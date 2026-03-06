import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingService {
  late IO.Socket socket;
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  // Replace with your local machine's IP address when testing on a physical device
  final String serverUrl = 'http://192.168.1.11:3000';

  Function(MediaStream stream)? onAddRemoteStream;
  Function(String message)? onMatchFound;
  Function()? onWaitingForMatch;
  Function()? onPartnerLeft;

  String? currentRoomId;

  Future<void>? _initWebRTCFuture;
  final List<RTCIceCandidate> _remoteCandidates = [];
  bool _isRemoteDescriptionSet = false;

  Future<void> _ensureWebRTCInit() {
    _initWebRTCFuture ??= _initWebRTC();
    return _initWebRTCFuture!;
  }

  void connect() {
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('Connected to Signaling Server: ${socket.id}');
    });

    socket.on('match_found', (data) async {
      print('Match found: $data');
      if (onMatchFound != null) onMatchFound!(data['message']);

      currentRoomId = data['roomId'];
      bool isCaller = data['isCaller'] ?? false;

      _remoteCandidates.clear();
      _isRemoteDescriptionSet = false;

      await _ensureWebRTCInit();

      if (isCaller) {
        final offer = await peerConnection?.createOffer();
        if (offer != null) {
          await peerConnection?.setLocalDescription(offer);
          socket.emit('webrtc_offer', {
            'offer': {'sdp': offer.sdp, 'type': offer.type},
            'roomId': currentRoomId,
          });
        }
      }
    });

    socket.on('waiting_for_match', (data) {
      if (onWaitingForMatch != null) onWaitingForMatch!();
    });

    socket.on('webrtc_offer', (data) async {
      print('Received WebRTC Offer');
      await _ensureWebRTCInit();
      await peerConnection?.setRemoteDescription(
        RTCSessionDescription(data['offer']['sdp'], data['offer']['type']),
      );
      _isRemoteDescriptionSet = true;
      _processIceCandidateQueue();

      final answer = await peerConnection?.createAnswer();
      if (answer != null) {
        await peerConnection?.setLocalDescription(answer);

        socket.emit('webrtc_answer', {
          'answer': {'sdp': answer.sdp, 'type': answer.type},
          'roomId': currentRoomId,
        });
      }
    });

    socket.on('webrtc_answer', (data) async {
      print('Received WebRTC Answer');
      await peerConnection?.setRemoteDescription(
        RTCSessionDescription(data['answer']['sdp'], data['answer']['type']),
      );
      _isRemoteDescriptionSet = true;
      _processIceCandidateQueue();
    });

    socket.on('webrtc_ice_candidate', (data) async {
      print('Received ICE Candidate');
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );
      if (_isRemoteDescriptionSet && peerConnection != null) {
        await peerConnection?.addCandidate(candidate);
      } else {
        _remoteCandidates.add(candidate);
      }
    });

    socket.on('partner_left', (_) {
      print('Partner left the room');
      if (onPartnerLeft != null) onPartnerLeft!();
      _closeWebRTC();
      disconnect();
    });
  }

  void _processIceCandidateQueue() {
    for (var candidate in _remoteCandidates) {
      peerConnection?.addCandidate(candidate);
    }
    _remoteCandidates.clear();
  }

  void findMatch(String role, String topic) {
    socket.emit('find_match', {
      'role': role,
      'topic': topic,
      'nickname': 'User', // dynamic later
      'avatar': '👤', // dynamic later
    });
  }

  Future<void> _initWebRTC() async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {'urls': 'stun:stun3.l.google.com:19302'},
        {'urls': 'stun:stun4.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    peerConnection = await createPeerConnection(configuration);

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

    peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams.first;
        try {
          Helper.setSpeakerphoneOn(
            true,
          ); // Ensure audio plays loud out of speaker
        } catch (e) {
          print('Error setting speakerphone: $e');
        }
        if (onAddRemoteStream != null) {
          onAddRemoteStream!(remoteStream!);
        }
      }
    };

    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });

    if (localStream != null) {
      for (var track in localStream!.getTracks()) {
        await peerConnection?.addTrack(track, localStream!);
      }
    }
  }

  void leaveSession(String roomId) {
    socket.emit('end_session', {'roomId': roomId});
    _closeWebRTC();
    disconnect();
  }

  void disconnect() {
    socket.disconnect();
    socket.dispose();
  }

  void _closeWebRTC() {
    localStream?.getTracks().forEach((track) => track.stop());
    localStream?.dispose();
    remoteStream?.getTracks().forEach((track) => track.stop());
    remoteStream?.dispose();
    peerConnection?.close();
    peerConnection?.dispose();
    peerConnection = null;
    localStream = null;
    remoteStream = null;
    currentRoomId = null;
    _initWebRTCFuture = null;
    _isRemoteDescriptionSet = false;
    _remoteCandidates.clear();
  }
}
