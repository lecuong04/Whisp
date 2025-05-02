import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:whisp/services/user_service.dart';
import 'package:whisp/services/webrtc_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomId;
  final bool isOffer;

  const VideoCallScreen({
    super.key,
    required this.roomId,
    required this.isOffer,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late WebRTCService webRTCService;
  bool isServiceInitialized = false;
  bool isClosed = false;

  @override
  void initState() {
    super.initState();
    webRTCService = WebRTCService(
      roomId: widget.roomId,
      selfId: UserService().id!,
      onlyAudio: false,
    );
    webRTCService
        .initialize()
        .then((_) {
          if (mounted) {
            setState(() {
              webRTCService.addListener(_onServiceUpdate);
              isServiceInitialized = true;
            });
          }
        })
        .catchError((e) {
          //print("Error initializing WebRTC Service: $e");
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Lỗi khởi tạo kết nối: $e')));
            // Navigator.pop(context);
          }
        });
    //_countDown();
  }

  // Future<void> _countDown() async {
  //   while (!_isServiceInitialized) {
  //     await Future.delayed(Duration(seconds: 1));
  //     if (_isClosed) return;
  //   }
  //   for (int i = 0; i <= 20; i++) {
  //     if (_isClosed || _webRTCService.isConnectionEstablished) return;
  //     await _performStartCall();
  //     await Future.delayed(Duration(seconds: 5));
  //   }
  //   _performHangup();
  // }

  // Hàm được gọi mỗi khi WebRTCService gọi notifyListeners()
  void _onServiceUpdate() {
    if (mounted) {
      if (webRTCService.isHangup && !isClosed) {
        isClosed = true;
        Navigator.pop(context);
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    webRTCService.removeListener(_onServiceUpdate);
    webRTCService.dispose();
    super.dispose();
  }

  // Hàm xử lý gác máy từ UI
  Future<void> _performHangup() async {
    try {
      await webRTCService.hangUp();
    } catch (e) {
      //print("Error during hangup: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi gác máy: $e')));
      }
    }
  }

  Future<void> _performStartCall() async {
    if (!isServiceInitialized || !webRTCService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dịch vụ chưa sẵn sàng, vui lòng đợi...')),
      );
      return;
    }
    try {
      await webRTCService.startCall();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang gửi lời mời cuộc gọi...')),
        );
      }
    } catch (e) {
      //print("Error starting call: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi bắt đầu cuộc gọi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child:
            !isServiceInitialized
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          // Video từ xa
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.all(4.0),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                              ),
                              child: RTCVideoView(
                                webRTCService.remoteRenderer,
                                mirror: false,
                                objectFit:
                                    RTCVideoViewObjectFit
                                        .RTCVideoViewObjectFitContain,
                              ),
                            ),
                          ),
                          if (webRTCService.localStream != null)
                            Positioned(
                              bottom: 16.0,
                              right: 16.0,
                              child: SizedBox(
                                width: 120,
                                height: 160,
                                child: RTCVideoView(
                                  webRTCService.localRenderer,
                                  mirror: true,
                                  objectFit:
                                      RTCVideoViewObjectFit
                                          .RTCVideoViewObjectFitCover,
                                ),
                              ),
                            )
                          else
                            Positioned(
                              bottom: 16.0,
                              right: 16.0,
                              child: Container(
                                width: 120,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(25),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.videocam_off,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          spacing: 10,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (!webRTCService.isConnectionEstablished &&
                                webRTCService.localStream != null)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.call),
                                label: const Text('Bắt đầu gọi'),
                                onPressed: _performStartCall,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),

                            if (isServiceInitialized)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.call_end),
                                label: const Text('Gác máy'),
                                onPressed: _performHangup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              ),

                            if (webRTCService.isConnectionEstablished) ...[
                              IconButton(
                                onPressed: webRTCService.toggleMic,
                                icon:
                                    webRTCService.isAudioOn
                                        ? Icon(Symbols.mic)
                                        : Icon(Symbols.mic_off),
                              ),
                              IconButton(
                                onPressed: webRTCService.toggleVideo,
                                icon:
                                    webRTCService.isVideoOn
                                        ? Icon(Symbols.videocam)
                                        : Icon(Symbols.videocam_off),
                              ),
                              IconButton(
                                onPressed: webRTCService.switchCamera,
                                icon: Icon(Symbols.switch_camera),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
