import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WebRTCService extends ChangeNotifier {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final supabase = Supabase.instance.client;
  final String selfId;
  final String roomId;
  final bool onlyAudio;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  // ignore: unused_field
  bool _offer = false;
  bool _isConnectionEstablished = false;
  bool _isInitialized = false;
  bool _isHangup = false;
  bool _isAudioOn = true;
  bool _isVideoOn = true;
  RealtimeChannel? _channel;

  bool get isAudioOn => _isAudioOn;
  bool get isVideoOn => _isVideoOn;
  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  MediaStream? get localStream => _localStream;
  bool get isConnectionEstablished => _isConnectionEstablished;
  bool get isInitialized => _isInitialized;
  bool get isHangup => _isHangup;

  late final Map<String, dynamic> _mediaConstraints = {
    'audio': _isAudioOn,
    'video': !onlyAudio ? {'facingMode': 'user'} : false,
  };
  late final Map<String, dynamic> _configuration;

  WebRTCService({
    required this.roomId,
    required this.selfId,
    this.onlyAudio = false,
    Map<String, dynamic>? iceServers,
  }) {
    if (onlyAudio) _isVideoOn = !onlyAudio;
    Map<String, dynamic> configuration = {"sdpSemantics": "unified-plan"};
    if (iceServers == null || iceServers.isEmpty) {
      configuration.addAll({
        "iceServers": [
          {"urls": "stun:stun.l.google.com:19302"},
          {"urls": "stun:stun.l.google.com:5349"},
          {"urls": "stun:stun1.l.google.com:3478"},
          {"urls": "stun:stun1.l.google.com:5349"},
          {"urls": "stun:stun2.l.google.com:19302"},
          {"urls": "stun:stun2.l.google.com:5349"},
          {"urls": "stun:stun3.l.google.com:3478"},
          {"urls": "stun:stun3.l.google.com:5349"},
          {"urls": "stun:stun4.l.google.com:19302"},
          {"urls": "stun:stun4.l.google.com:5349"},
        ],
      });
    } else {
      configuration.addAll(iceServers);
    }
    _configuration = configuration;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    print('Initializing WebRTC Service...');
    await _initializeRenderers();
    _connectSupabaseRealtime();
    await _createPeerConnection();
    await _getMediaAndAddToConnection();
    _isInitialized = true;
    notifyListeners();
    print('WebRTC Service Initialized.');
  }

  @override
  void dispose() {
    print('Disposing WebRTC Service...');
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _peerConnection?.close();
    _peerConnection = null;
    _channel?.unsubscribe();
    _isInitialized = false;
    _isConnectionEstablished = false;
    super.dispose();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _connectSupabaseRealtime() {
    final channelName = 'WebRTC-$roomId';
    print('Connecting to Supabase channel: $channelName');
    _channel = supabase.channel(
      channelName,
      opts: const RealtimeChannelConfig(ack: true, self: false),
    );

    _channel!
        .onBroadcast(
          event: 'signal',
          callback: (payload) {
            if (payload['senderId'] != selfId) {
              var signal = payload['data'];
              print('Received signal: $signal');
              if (signal['type'] == 'offer') {
                _handleOffer(signal);
              } else if (signal['type'] == 'answer') {
                _handleAnswer(signal);
              } else if (signal['type'] == 'candidate') {
                _handleCandidate(signal);
              } else if (signal['type'] == 'hangup') {
                _handleHangup(notifyPeer: false);
              }
            }
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            print('Successfully subscribed to Supabase channel: $channelName');
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            print('Error subscribing to channel: $error');
          }
        });
  }

  Future<void> _createPeerConnection() async {
    print('Creating Peer Connection...');
    _peerConnection = await createPeerConnection(_configuration, {});

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      print('Got ICE candidate: ${candidate.toMap()}');
      _sendSignal({'type': 'candidate', 'candidate': candidate.toMap()});
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE Connection State changed: $state');
      bool connected =
          state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted;
      if (_isConnectionEstablished != connected) {
        _isConnectionEstablished = connected;
        notifyListeners();
      }

      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        _handleHangup(notifyPeer: false);
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      print("Remote track received: ${event.track.kind}");
      if (event.streams.isNotEmpty) {
        var stream = event.streams[0];
        print("Assigning remote stream: ${stream.id}");
        _remoteStream = stream;
        _remoteRenderer.srcObject = _remoteStream;
        notifyListeners();
      }
    };

    _peerConnection!.onRemoveStream = (MediaStream stream) {
      print("Remote stream removed: ${stream.id}");
      _handleHangup(notifyPeer: false);
    };
    print('Peer Connection created.');
  }

  Future<void> _getMediaAndAddToConnection() async {
    if (_peerConnection == null) {
      print("PeerConnection not ready for getting media.");
      return;
    }
    try {
      print('Getting user media...');
      _localStream = await navigator.mediaDevices.getUserMedia(
        _mediaConstraints,
      );
      print('Local stream obtained: ${_localStream?.id}');
      _localRenderer.srcObject = _localStream;

      _localStream?.getTracks().forEach((track) {
        print('Adding local track: ${track.kind}');
        _peerConnection?.addTrack(track, _localStream!);
      });
      print('Local tracks added to Peer Connection.');
      notifyListeners();
    } catch (e) {
      print('Error getting user media: $e');
    }
  }

  Future<void> _sendSignal(Map<String, dynamic> signal) async {
    if (_channel == null) {
      print('Supabase channel is not initialized.');
      return;
    }
    print('Sending signal: $signal');
    try {
      await _channel!.sendBroadcastMessage(
        event: 'signal',
        payload: {'senderId': selfId, 'data': signal},
      );
    } catch (e) {
      print('Error sending signal via Supabase: $e');
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> offerData) async {
    if (_peerConnection == null) return;
    print('Received Offer');
    RTCSessionDescription offer = RTCSessionDescription(
      offerData['sdp'],
      offerData['type'],
    );
    try {
      await _peerConnection!.setRemoteDescription(offer);
      print('Remote Description (Offer) set successfully.');
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      print('Answer created successfully.');
      await _peerConnection!.setLocalDescription(answer);
      print('Local Description (Answer) set successfully.');
      _sendSignal({
        'type': 'answer',
        'sdp': answer.sdp,
        'type_desc': answer.type,
      });
    } catch (e) {
      print('Error handling offer: $e');
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> answerData) async {
    if (_peerConnection == null) return;
    print('Received Answer');
    RTCSessionDescription answer = RTCSessionDescription(
      answerData['sdp'],
      answerData['type_desc'] ?? answerData['type'] ?? 'answer',
    );
    try {
      await _peerConnection!.setRemoteDescription(answer);
      print('Remote Description (Answer) set successfully.');
    } catch (e) {
      print('Error handling answer: $e');
    }
  }

  Future<void> _handleCandidate(Map<String, dynamic> candidateData) async {
    if (_peerConnection == null) return;
    print('Received ICE Candidate');
    try {
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateData['candidate']['candidate'],
        candidateData['candidate']['sdpMid'],
        candidateData['candidate']['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
      print('ICE Candidate added successfully.');
    } catch (e) {
      print('Error adding received ICE candidate: $e');
    }
  }

  void _handleHangup({bool notifyPeer = false}) {
    print("Handling hangup. Notify peer: $notifyPeer");
    if (!_isInitialized) return;
    if (notifyPeer) _sendSignal({'type': 'hangup'});

    _isConnectionEstablished = false;
    _remoteStream = null;
    _remoteRenderer.srcObject = null;
    _peerConnection?.close();
    _isHangup = true;
    notifyListeners();
  }

  void toggleMic() {
    _isAudioOn = !_isAudioOn;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = _isAudioOn;
    });
    notifyListeners();
  }

  void toggleVideo() {
    if (onlyAudio) return;
    _isVideoOn = !_isVideoOn;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = _isVideoOn;
    });
    notifyListeners();
  }

  void switchCamera() {
    if (onlyAudio) return;
    _localStream?.getVideoTracks().forEach((track) {
      Helper.switchCamera(track);
    });
    notifyListeners();
  }

  Future<void> startCall() async {
    if (_peerConnection == null || _localStream == null || _channel == null) {
      print('Service not ready to start call.');
      return;
    }
    if (_isConnectionEstablished) {
      print("Call already established.");
      return;
    }
    print('Starting call by creating Offer...');
    _offer = true;
    try {
      RTCSessionDescription offer = await _peerConnection!.createOffer({
        'offerToReceiveVideo': !onlyAudio,
        'offerToReceiveAudio': true,
      });
      print('Offer created successfully.');
      await _peerConnection!.setLocalDescription(offer);
      print('Local Description (Offer) set successfully.');
      _sendSignal({'type': 'offer', 'sdp': offer.sdp, 'type_desc': offer.type});
      print('Offer sent.');
    } catch (e) {
      print('Error creating or sending offer: $e');
    }
  }

  Future<void> hangUp() async {
    print('Initiating hangup...');
    _handleHangup(notifyPeer: true);
  }
}
