import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:whisp/models/call_info.dart';
import 'package:whisp/models/call_manager.dart';
import 'package:whisp/services/call_service.dart';
import 'package:whisp/services/user_service.dart';

class VideoCallScreen extends StatefulWidget {
  final CallInfo? callInfo;
  final String? callId;

  const VideoCallScreen({super.key, this.callInfo, this.callId})
    : assert(
        (callInfo == null && callId != null) ||
            (callInfo != null && callId == null),
      );

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  Timer? timeOut;
  Timer? turnExpiry;
  late CallInfo callInfo;

  CallManager callManager = CallManager();
  bool isServiceInitialized = false;
  bool isClosed = false;
  Map<String, dynamic>? otherUser;

  @override
  void initState() {
    super.initState();
    initializeCall();
  }

  Future<void> initializeCall() async {
    if (widget.callId != null) {
      callInfo = (await CallService().getCallInfo(widget.callId!))!;
    } else {
      callInfo = widget.callInfo!;
    }
    CallService().updateCallWhenClick(callInfo.id);
    if (callInfo.callerId != UserService().id) {
      otherUser = await UserService().getUser(callInfo.callerId);
    } else {
      otherUser = await UserService().getUser(callInfo.receiverId);
    }
    if (callManager.service == null) {
      if (!(await callManager.createInstance(
        callId: callInfo.id,
        selfId: UserService().id!,
        isVideoCall: !callInfo.isVideoCall,
        iceServers: callInfo.iceServers,
      ))) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khởi tạo kết nối!')));
        Navigator.pop(context);
      }
    }
    callManager.service!.addListener(onServiceUpdate);
    setState(() {
      if (callManager.service != null) {
        isServiceInitialized = true;
      } else {
        Navigator.pop(context);
      }
    });
    var now = DateTime.now().toUtc();
    if (callInfo.status != 'pending' && callInfo.status != 'accepted') {
      Navigator.pop(context);
      return;
    }
    timeOut = Timer(
      callInfo.createdAt
          .add(Duration(seconds: callInfo.timeout))
          .difference(now),
      () async {
        if (callManager.service != null &&
            !callManager.service!.isConnectionEstablished) {
          CallService().endCall(callInfo.id);
          Navigator.pop(context);
        }
      },
    );
  }

  void onServiceUpdate() {
    if (mounted) {
      setState(() {});
      if (callManager.service!.isHangup && !isClosed) {
        isClosed = true;
        CallService().endCall(callInfo.id);
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    callManager.service?.removeListener(onServiceUpdate);
    if (callManager.service != null &&
        !callManager.service!.isConnectionEstablished) {
      try {
        callManager.removeInstance();
      } catch (e) {
        print(e);
      }
    }
    timeOut?.cancel();
    turnExpiry?.cancel();
    super.dispose();
  }

  // Hàm xử lý gác máy từ UI
  Future<void> performHangup() async {
    try {
      await callManager.service!.hangUp();
    } catch (e) {
      print("Error during hangup: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi gác máy: $e')));
      }
    }
  }

  Future<void> performStartCall() async {
    if (!isServiceInitialized ||
        (callManager.service != null && !callManager.service!.isInitialized)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dịch vụ chưa sẵn sàng, vui lòng đợi...')),
      );
      return;
    }
    try {
      await callManager.service!.startCall();
      CallService().acceptCall(callInfo.id);
      turnExpiry = Timer(
        callInfo.createdAt
            .add(Duration(hours: 4))
            .difference(DateTime.now().toUtc()),
        () async {
          await performHangup();
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang gửi lời mời cuộc gọi...')),
        );
      }
    } catch (e) {
      print("Error starting call: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi bắt đầu cuộc gọi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isServiceInitialized) {
      return Scaffold(
        body: SafeArea(child: const Center(child: CircularProgressIndicator())),
      );
    }
    var service = callManager.service!;
    return Scaffold(
      appBar: AppBar(
        title: Text(otherUser!["full_name"]),
        automaticallyImplyLeading: false,
        leading:
            service.isConnectionEstablished
                ? IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.arrow_back),
                )
                : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (callInfo.isVideoCall) ...[
                    // Video từ xa
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(4.0),
                        decoration: const BoxDecoration(color: Colors.black),
                        child: RTCVideoView(
                          service.remoteRenderer,
                          mirror: false,
                          filterQuality: FilterQuality.medium,
                          objectFit:
                              RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitContain,
                        ),
                      ),
                    ),
                    if (service.localStream != null)
                      // Video từ local
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
                            border: Border.all(color: Colors.white, width: 1),
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
                  ] else ...[
                    Positioned.fill(
                      child: Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage:
                              otherUser!["avatar_url"] != null
                                  ? CachedNetworkImageProvider(
                                    otherUser!["avatar_url"],
                                  )
                                  : null,
                        ),
                      ),
                    ),
                  ],
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
                    if (callInfo.callerId != UserService().id &&
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

                    ElevatedButton.icon(
                      icon: const Icon(Icons.call_end),
                      label: const Text('Kết thúc'),
                      onPressed: () async {
                        await performHangup();
                      },
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
                      if (callInfo.isVideoCall) ...[
                        IconButton(
                          onPressed: service.toggleVideo,
                          icon:
                              service.isVideoOn
                                  ? Icon(Icons.videocam)
                                  : Icon(Icons.videocam_off),
                        ),
                        IconButton(
                          onPressed: service.switchCamera,
                          icon: Icon(Icons.switch_camera),
                        ),
                      ],
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
