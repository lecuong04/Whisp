import 'package:flutter/foundation.dart';
import 'package:whisp/services/webrtc_service.dart';

class CallManager extends ChangeNotifier {
  WebRTCService? _service;

  WebRTCService? get service => _service;

  CallManager._();

  static final CallManager _instance = CallManager._();

  factory CallManager() {
    return _instance;
  }

  Future<bool> createInstance({
    required String callId,
    required String selfId,
    bool isVideoCall = false,
    Map<String, dynamic>? iceServers,
  }) async {
    try {
      _service = WebRTCService(
        callId: callId,
        selfId: selfId,
        onlyAudio: isVideoCall,
        iceServers: iceServers,
      );
      await _service!.initialize();
      _service!.addListener(_onServiceUpdate);
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  void _onServiceUpdate() {
    notifyListeners();
  }

  void removeInstance() {
    _service?.dispose();
    _service = null;
    notifyListeners();
  }
}
