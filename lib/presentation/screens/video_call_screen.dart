import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:whisp/models/call_info.dart';
import 'package:whisp/services/user_service.dart';
import 'package:whisp/services/webrtc_service.dart';

class VideoCallScreen extends StatefulWidget {
  final CallInfo callInfo;

  const VideoCallScreen({super.key, required this.callInfo});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late WebRTCService service;
  late Timer timeOut;
  bool isServiceInitialized = false;
  bool isClosed = false;
  Map<String, dynamic>? otherUser;

  @override
  void initState() {
    super.initState();
    initWebRTC();
  }

  Future<void> initWebRTC() async {
    if (widget.callInfo.callerId != UserService().id) {
      otherUser = await UserService().getUser(widget.callInfo.callerId);
    } else {
      otherUser = await UserService().getUser(widget.callInfo.calleeId);
    }
    service = WebRTCService(
      roomId: widget.callInfo.id,
      selfId: UserService().id!,
      onlyAudio: !widget.callInfo.videoEnabled,
    );
    try {
      await service.initialize();
      setState(() {
        service.addListener(onServiceUpdate);
        isServiceInitialized = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khởi tạo kết nối: $e')));
      dispose();
    }
    var now = DateTime.now().toUtc();
    if (now.compareTo(widget.callInfo.expiresAt) > 0) {
      Navigator.pop(context);
      return;
    }
    timeOut = Timer(widget.callInfo.expiresAt.difference(now), () async {
      if (!service.isConnectionEstablished) {
        Navigator.pop(context);
      }
    });
  }

  void onServiceUpdate() {
    if (mounted) {
      setState(() {});
      if (service.isHangup && !isClosed) {
        isClosed = true;
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    timeOut.cancel();
    service.removeListener(onServiceUpdate);
    service.dispose();
    super.dispose();
  }

  // Hàm xử lý gác máy từ UI
  Future<void> performHangup() async {
    try {
      await service.hangUp();
    } catch (e) {
      //print("Error during hangup: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi gác máy: $e')));
      }
    }
  }

  Future<void> performStartCall() async {
    if (!isServiceInitialized || !service.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dịch vụ chưa sẵn sàng, vui lòng đợi...')),
      );
      return;
    }
    try {
      await service.startCall();
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
      appBar: AppBar(
        title: isServiceInitialized ? Text(otherUser!["full_name"]) : null,
        automaticallyImplyLeading: false,
        leading: IconButton(onPressed: () {}, icon: Icon(Icons.arrow_back)),
      ),
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
                                service.remoteRenderer,
                                mirror: false,
                                objectFit:
                                    RTCVideoViewObjectFit
                                        .RTCVideoViewObjectFitContain,
                              ),
                            ),
                          ),
                          if (service.localStream != null)
                            Positioned(
                              bottom: 16.0,
                              right: 16.0,
                              child: SizedBox(
                                width: 120,
                                height: 160,
                                child: RTCVideoView(
                                  service.localRenderer,
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
                            if (widget.callInfo.callerId != UserService().id &&
                                !service.isConnectionEstablished &&
                                service.localStream != null)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.call),
                                label: const Text('Bắt đầu gọi'),
                                onPressed: performStartCall,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),

                            if (isServiceInitialized)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.call_end),
                                label: const Text('Gác máy'),
                                onPressed: performHangup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              ),

                            if (service.isConnectionEstablished) ...[
                              IconButton(
                                onPressed: service.toggleMic,
                                icon:
                                    service.isAudioOn
                                        ? Icon(Icons.mic)
                                        : Icon(Icons.mic_off),
                              ),
                              IconButton(
                                onPressed: service.toggleVideo,
                                icon:
                                    service.isVideoOn
                                        ? Icon(Icons.videocam)
                                        : Icon(Icons.videocam_off),
                              ),
                              if (service.isVideoOn)
                                IconButton(
                                  onPressed: service.switchCamera,
                                  icon: Icon(Icons.switch_camera),
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
