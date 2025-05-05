import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whisp/utils/constants.dart';

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
    super.key,
    required this.messages,
    required this.myId,
    required this.friendImage,
    required this.scrollController,
    required this.isLoadingMore,
    required this.hasMoreMessages,
    required this.selectedMessages,
    required this.onMessageTap,
  });

  @override
  State createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final Set<int> _showTimestampIndices = {};

  void _toggleTimestamp(int index) {
    setState(() {
      if (_showTimestampIndices.contains(index)) {
        _showTimestampIndices.remove(index);
      } else {
        _showTimestampIndices.add(index);
      }
    });
  }

  Widget _buildMessageContent(Map<String, dynamic> message) {
    final messageType = message['message_type'] as String;
    final content = message['content'] as String;

    Widget contentWidget;
    switch (messageType) {
      case 'image':
        contentWidget = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: content,
            width: 200,
            fit: BoxFit.cover,
            placeholder: (context, url) => const CircularProgressIndicator(),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        );
        break;
      case 'video':
        final thumbnailUrl = content;
        contentWidget = GestureDetector(
          onTap: () async {
            final url = Uri.parse(content);
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  width: 200,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(
                        width: 200,
                        height: 120,
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        width: 200,
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.play_circle_filled,
                          size: 50,
                          color: Colors.blue,
                        ),
                      ),
                ),
              ),
            ],
          ),
        );
        break;
      case 'file':
        contentWidget = GestureDetector(
          onTap: () async {
            final url = Uri.parse(content);
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insert_drive_file, color: Colors.blue),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    content.split('/').last,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
        break;
      case 'call':
        final callInfo = message['call_info'] as Map<String, dynamic>?;
        if (callInfo == null) {
          contentWidget = const Text(
            'Cuộc gọi không xác định',
            style: TextStyle(fontSize: 16),
          );
        } else {
          final isVideoCall = callInfo['is_video_call'] as bool;
          final status = callInfo['status'] as String;
          String displayText;
          IconData icon;

          switch (status) {
            case 'accepted':
            case 'ended':
              displayText =
                  isVideoCall
                      ? 'Cuộc gọi video đã kết thúc'
                      : 'Cuộc gọi đã kết thúc';
              icon = isVideoCall ? Icons.videocam : Icons.phone;
              break;
            case 'missed':
              displayText = isVideoCall ? 'Cuộc gọi video nhỡ' : 'Cuộc gọi nhỡ';
              icon = isVideoCall ? Icons.videocam_off : Icons.phone_missed;
              break;
            case 'rejected':
              displayText =
                  isVideoCall
                      ? 'Cuộc gọi video bị từ chối'
                      : 'Cuộc gọi bị từ chối';
              icon = isVideoCall ? Icons.videocam_off : Icons.phone_missed;
              break;
            default:
              displayText = 'Cuộc gọi không xác định';
              icon = Icons.phone;
          }

          contentWidget = Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color:
                      status == 'missed' || status == "rejected"
                          ? Colors.red
                          : Colors.blue,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    displayText,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }
        break;
      case 'text':
      default:
        contentWidget = Text(content, style: const TextStyle(fontSize: 16));
        break;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * MESSAGE_BOX_MAX_SIZE,
      ),
      child: contentWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.messages.length + 1;

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          if (widget.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(10),
              child: Center(child: CircularProgressIndicator()),
            );
          } else if (!widget.hasMoreMessages) {
            return const Padding(
              padding: EdgeInsets.all(10),
              child: Center(
                child: Text(
                  'Không còn tin nhắn',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            );
          } else {
            return const SizedBox.shrink();
          }
        }

        final messageIndex = index - 1;
        final message = widget.messages[messageIndex];
        final isMe = message['sender_id'] == widget.myId;
        final showTimestamp = _showTimestampIndices.contains(messageIndex);
        final messageType = message['message_type'] as String;

        bool isReadByAll = false;
        if (isMe && message['message_statuses'] != null) {
          final statuses = message['message_statuses'] as List<dynamic>;
          isReadByAll = statuses.every(
            (status) =>
                status['user_id'] == widget.myId || status['is_read'] == true,
          );
        }

        return GestureDetector(
          onTap: () {
            _toggleTimestamp(messageIndex);
            widget.onMessageTap(messageIndex);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            child: Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  CircleAvatar(
                    backgroundImage:
                        widget.friendImage.isNotEmpty
                            ? NetworkImage(widget.friendImage)
                            : null,
                    radius: 15,
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment:
                        isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding:
                            messageType == "text" ||
                                    messageType == 'file' ||
                                    messageType == 'call'
                                ? const EdgeInsets.all(10)
                                : null,
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _buildMessageContent(message),
                      ),
                      const SizedBox(height: 5),
                      if (showTimestamp)
                        Text(
                          _formatTimestamp(message['sent_at']),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      if (isMe && messageIndex == widget.messages.length - 1)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isReadByAll
                                  ? FontAwesomeIcons.solidCircleCheck
                                  : FontAwesomeIcons.circleCheck,
                              size: 14,
                              color: isReadByAll ? Colors.blue : Colors.grey,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isReadByAll ? 'Đã xem' : 'Đã gửi',
                              style: TextStyle(
                                fontSize: 12,
                                color: isReadByAll ? Colors.blue : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (isMe) const SizedBox(width: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(String sentAt) {
    final dateTime = DateTime.parse(sentAt).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    if (messageDate == today) {
      return '$hour:$minute';
    } else {
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      return '$day/$month $hour:$minute';
    }
  }
}
