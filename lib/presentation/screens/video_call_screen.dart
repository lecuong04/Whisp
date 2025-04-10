import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:whisp/services/webrtc_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomId;

  const VideoCallScreen({super.key, required this.roomId});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  // Tạo instance của WebRTCService
  late WebRTCService _webRTCService;
  bool _isServiceInitialized = false;
  bool _isClosed = false;

  @override
  void initState() {
    super.initState();
    _webRTCService = WebRTCService(roomId: widget.roomId);
    // Khởi tạo service và gọi hàm initialize của nó
    _webRTCService
        .initialize()
        .then((_) {
          // Sau khi service khởi tạo xong, thêm listener
          if (mounted) {
            // Kiểm tra widget còn tồn tại
            setState(() {
              _webRTCService.addListener(_onServiceUpdate);
              _isServiceInitialized = true; // Đánh dấu service đã sẵn sàng
            });
          }
        })
        .catchError((e) {
          //print("Error initializing WebRTC Service: $e");
          // Hiển thị lỗi cho người dùng nếu cần
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khởi tạo kết nối: $e')));
            // Có thể pop màn hình nếu khởi tạo thất bại nghiêm trọng
            // Navigator.pop(context);
          }
        });
    //_countDown();
  }

  Future<void> _countDown() async {
    while (!_isServiceInitialized) {
      await Future.delayed(Duration(seconds: 1));
      if (_isClosed) return;
    }
    for (int i = 0; i <= 20; i++) {
      if (_isClosed || _webRTCService.isConnectionEstablished) return;
      await _performStartCall();
      await Future.delayed(Duration(seconds: 5));
    }
    _performHangup();
  }

  // Hàm được gọi mỗi khi WebRTCService gọi notifyListeners()
  void _onServiceUpdate() {
    // Chỉ cần gọi setState để rebuild UI với dữ liệu mới từ service
    if (mounted) {
      // Luôn kiểm tra mounted trước khi gọi setState
      if (_webRTCService.isClosed && !_isClosed) {
        _isClosed = true;
        Navigator.pop(context);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    // Gỡ listener và dispose service khi widget bị hủy
    _webRTCService.removeListener(_onServiceUpdate);
    _webRTCService.dispose();
    super.dispose();
  }

  // Hàm xử lý gác máy từ UI
  Future<void> _performHangup() async {
    try {
      await _webRTCService.hangUp();
      // Sau khi hangUp thành công, quay lại màn hình trước
    } catch (e) {
      //print("Error during hangup: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi gác máy: $e')));
      }
    }
  }

  // Hàm xử lý bắt đầu gọi từ UI
  Future<void> _performStartCall() async {
    if (!_isServiceInitialized || !_webRTCService.isInitialized) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dịch vụ chưa sẵn sàng, vui lòng đợi...')));
      return;
    }
    try {
      await _webRTCService.startCall();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang gửi lời mời cuộc gọi...')));
      }
    } catch (e) {
      //print("Error starting call: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi bắt đầu cuộc gọi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Phòng: ${widget.roomId}')),
      body:
          !_isServiceInitialized // Hiển thị loading nếu service chưa khởi tạo xong
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // --- Vùng hiển thị video ---
                  Expanded(
                    child: Stack(
                      children: [
                        // Video từ xa
                        Positioned.fill(
                          child: Container(
                            key: const Key('remote_video'),
                            margin: const EdgeInsets.all(4.0),
                            decoration: const BoxDecoration(color: Colors.black54),
                            // Lấy renderer từ service
                            child: RTCVideoView(
                              _webRTCService.remoteRenderer,
                              mirror: false,
                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                            ),
                          ),
                        ),
                        // Video cục bộ (chỉ hiển thị khi có stream local)
                        if (_webRTCService.localStream != null)
                          Positioned(
                            bottom: 16.0,
                            right: 16.0,
                            child: SizedBox(
                              width: 120,
                              height: 160,
                              // Lấy renderer từ service
                              child: RTCVideoView(
                                _webRTCService.localRenderer,
                                mirror: true,
                                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                              ),
                            ),
                          )
                        else // Hiển thị placeholder nếu chưa có stream local
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
                              child: const Center(child: Icon(Icons.videocam_off, color: Colors.white, size: 40)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // --- Vùng điều khiển ---
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        spacing: 10,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Nút bắt đầu gọi (chỉ hiển thị nếu chưa kết nối và có stream local)
                          if (!_webRTCService.isConnectionEstablished && _webRTCService.localStream != null)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.call),
                              label: const Text('Bắt đầu gọi'),
                              onPressed: _performStartCall, // Gọi hàm xử lý bắt đầu gọi
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),

                          // Nút gác máy (luôn hiển thị khi đã khởi tạo)
                          if (_isServiceInitialized)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.call_end),
                              label: const Text('Gác máy'),
                              onPressed: _performHangup,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
