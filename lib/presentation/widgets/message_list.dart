import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageList extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  final String myId;
  final String friendImage;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final bool hasMoreMessages;
  final Set<int> selectedMessages;
  final Function(int) onMessageTap;

  const MessageList({
    Key? key,
    required this.messages,
    required this.myId,
    required this.friendImage,
    required this.scrollController,
    required this.isLoadingMore,
    required this.hasMoreMessages,
    required this.selectedMessages,
    required this.onMessageTap,
  }) : super(key: key);

  @override
  _MessageListState createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  bool _showEndOfChatMessage = false;
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, bool> _videoInitialized =
      {}; // Theo dõi trạng thái khởi tạo
  final Map<String, String> _videoErrors = {}; // Lưu lỗi của từng video

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Xóa các controller không còn trong danh sách tin nhắn hiển thị
    final visibleMessageIds =
        widget.messages.map((m) => m['id'].toString()).toSet();
    _videoControllers.removeWhere((id, controller) {
      if (!visibleMessageIds.contains(id)) {
        controller.dispose();
        return true;
      }
      return false;
    });
    _videoInitialized.removeWhere((id, _) => !visibleMessageIds.contains(id));
    _videoErrors.removeWhere((id, _) => !visibleMessageIds.contains(id));

    if (!widget.hasMoreMessages && oldWidget.hasMoreMessages) {
      setState(() {
        _showEndOfChatMessage = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showEndOfChatMessage = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeVideoController(
    String messageId,
    String mediaUrl,
  ) async {
    if (_videoInitialized[messageId] == true) return; // Tránh khởi tạo lại

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
      _videoControllers[messageId] = controller;
      await controller.initialize();
      if (mounted) {
        setState(() {
          _videoInitialized[messageId] = true;
          _videoErrors.remove(messageId);
        });
      }
    } catch (error) {
      print("Error initializing video for message $messageId: $error");
      if (mounted) {
        setState(() {
          _videoInitialized[messageId] = false;
          _videoErrors[messageId] = error.toString();
        });
      }
    }
  }

  Widget _buildMessageContent(
    Map<String, dynamic> message,
    bool isMe,
    double maxWidth,
  ) {
    final type = message['type'] ?? 'text';

    switch (type) {
      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            message['media_url'],
            width: maxWidth * 0.8,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) =>
                    const Icon(Icons.error, color: Colors.red),
          ),
        );
      case 'video':
        final messageId = message['id'].toString();
        final mediaUrl = message['media_url'];

        // Khởi tạo controller nếu chưa có
        if (!_videoControllers.containsKey(messageId) &&
            !_videoInitialized.containsKey(messageId)) {
          _videoInitialized[messageId] = false; // Đánh dấu đang khởi tạo
          _initializeVideoController(messageId, mediaUrl);
        }

        final controller = _videoControllers[messageId];
        final isInitialized = _videoInitialized[messageId] ?? false;
        final error = _videoErrors[messageId];

        return Column(
          children: [
            if (isInitialized && controller != null)
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              )
            else if (error != null)
              const Text(
                'Không thể phát video',
                style: TextStyle(color: Colors.red),
              )
            else
              const CircularProgressIndicator(),
            if (isInitialized && controller != null)
              IconButton(
                icon: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: isMe ? Colors.white : Colors.black,
                ),
                onPressed: () {
                  setState(() {
                    if (controller.value.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  });
                },
              ),
          ],
        );
      case 'file':
        return GestureDetector(
          onTap: () async {
            final url = message['media_url'];
            if (await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(Uri.parse(url));
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file, color: Colors.grey),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message['file_name'] ?? 'Tệp',
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'text':
      default:
        return Text(
          message['text'] ?? '',
          style: TextStyle(color: isMe ? Colors.white : Colors.black),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    double maxWidth = MediaQuery.of(context).size.width * (2 / 3);

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(10),
      itemCount:
          widget.messages.length +
          (widget.isLoadingMore ? 1 : 0) +
          (_showEndOfChatMessage && !widget.hasMoreMessages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0 &&
            (widget.isLoadingMore ||
                (_showEndOfChatMessage && !widget.hasMoreMessages))) {
          if (widget.isLoadingMore) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_showEndOfChatMessage && !widget.hasMoreMessages) {
            return const Center(child: Text("Đã load hết tin nhắn"));
          }
        }

        final adjustedIndex =
            (widget.isLoadingMore ||
                    (_showEndOfChatMessage && !widget.hasMoreMessages))
                ? index - 1
                : index;
        if (adjustedIndex < 0) return const SizedBox.shrink();

        final message = widget.messages[adjustedIndex];
        bool isMe = message['sender_id'] == widget.myId;
        bool isSelected = widget.selectedMessages.contains(adjustedIndex);

        bool showAvatar =
            !isMe &&
            (adjustedIndex == 0 ||
                widget.messages[adjustedIndex]['sender_id'] !=
                    widget.messages[adjustedIndex - 1]['sender_id']);

        return GestureDetector(
          onTap: () => widget.onMessageTap(adjustedIndex),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8.0),
                  child:
                      showAvatar
                          ? CircleAvatar(
                            backgroundImage: NetworkImage(widget.friendImage),
                            radius: 12,
                          )
                          : const SizedBox(width: 25),
                ),
              Expanded(
                child: Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment:
                        isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMessageContent(message, isMe, maxWidth),
                          ],
                        ),
                      ),
                      if (isSelected && message['timestamp'] != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: Text(
                            DateFormat(
                              'HH:mm',
                            ).format(DateTime.parse(message['timestamp'])),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
