import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whisp/presentation/widgets/audio_player_modal.dart';
import 'package:whisp/presentation/widgets/image_thumbnail.dart';
import 'package:whisp/presentation/widgets/video_thumbnail.dart';
import 'package:whisp/utils/constants.dart';
import 'package:whisp/utils/helpers.dart';

class MessageList extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  final String myId;
  final String friendImage;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final bool hasMoreMessages;
  final Set<int> selectedMessages;
  final Function(int) onMessageHold;
  final String? targetMessageId;

  const MessageList({
    super.key,
    required this.messages,
    required this.myId,
    required this.friendImage,
    required this.scrollController,
    required this.isLoadingMore,
    required this.hasMoreMessages,
    required this.selectedMessages,
    required this.onMessageHold,
    this.targetMessageId,
  });

  @override
  State createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final Set<int> showTimestampIndices = {};

  void toggleTimestamp(int index) {
    setState(() {
      if (showTimestampIndices.contains(index)) {
        showTimestampIndices.remove(index);
      } else {
        showTimestampIndices.add(index);
      }
    });
  }

  bool isLastInSequence(int index) {
    if (index >= widget.messages.length - 1) {
      return true;
    }
    final currentMessage = widget.messages[index];
    final nextMessage = widget.messages[index + 1];
    return currentMessage['sender_id'] != nextMessage['sender_id'];
  }

  String formatTimestamp(String sentAt) {
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

  static Widget buildMessageContent(
    BuildContext context,
    Map<String, dynamic> message,
    String? targetMessageId,
  ) {
    final messageType = message['message_type'] as String;
    final content = message['content'] as String;
    final isTargetMessage = message['id'] == targetMessageId;

    Widget contentWidget;
    switch (messageType) {
      case 'image':
      case 'video':
      case 'file':
      case 'audio':
        {
          contentWidget = GestureDetector(
            onDoubleTap: () async {
              switch (messageType) {
                case "file":
                  {
                    final url = Uri.parse(content);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                    break;
                  }
                case "image":
                  {
                    await ImageThumbnail.imageViewer(
                      context: context,
                      url: content,
                    );
                    break;
                  }
                case "video":
                  {
                    await VideoThumbnail.videoPlayer(
                      context: context,
                      url: content,
                    );
                    break;
                  }
                case "audio":
                  {
                    await showModalBottomSheet(
                      context: context,
                      builder: (context) => AudioPlayerModal(url: content),
                    );
                    break;
                  }
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(switch (messageType) {
                  "video" => Icons.video_file_outlined,
                  "file" => Icons.insert_drive_file_outlined,
                  "audio" => Icons.audio_file_outlined,
                  "image" => Icons.image_outlined,
                  _ => Icons.question_mark,
                }, color: Colors.blue),
                const SizedBox(width: 5),
                Flexible(
                  child: TextScroll(
                    getFileNameFromSupabaseStorage(content),
                    mode: TextScrollMode.bouncing,
                    velocity: Velocity(pixelsPerSecond: Offset(30, 0)),
                    delayBefore: Duration(seconds: 4),
                    pauseBetween: Duration(seconds: 3),
                    pauseOnBounce: Duration(seconds: 5),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          isTargetMessage ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
          break;
        }
      case 'call':
        {
          final callInfo = message['call_info'] as Map<String, dynamic>?;
          if (callInfo == null) {
            contentWidget = Text(
              'Cuộc gọi không xác định',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    isTargetMessage ? FontWeight.bold : FontWeight.normal,
              ),
            );
          } else {
            final isVideoCall = callInfo['is_video_call'] as bool;
            final status = callInfo['status'] as String;
            String displayText;
            IconData icon;

            switch (status) {
              case 'accepted':
                displayText = "Cuộc gọi đang diễn ra";
                icon = isVideoCall ? Icons.videocam : Icons.phone;
                break;
              case 'ended':
                displayText =
                    isVideoCall
                        ? 'Cuộc gọi video đã kết thúc'
                        : 'Cuộc gọi đã kết thúc';
                icon = isVideoCall ? Icons.videocam : Icons.phone;
                break;
              case 'missed':
                displayText =
                    isVideoCall ? 'Cuộc gọi video nhỡ' : 'Cuộc gọi nhỡ';
                icon = isVideoCall ? Icons.videocam_off : Icons.phone_missed;
                break;
              case 'rejected':
                displayText =
                    isVideoCall
                        ? 'Cuộc gọi video bị từ chối'
                        : 'Cuộc gọi bị từ chối';
                icon = isVideoCall ? Icons.videocam_off : Icons.phone_missed;
                break;
              case 'pending':
                displayText = "Cuộc gọi chờ chấp nhận";
                icon = isVideoCall ? Icons.videocam : Icons.phone;
                break;
              default:
                displayText = 'Cuộc gọi không xác định';
                icon = Icons.phone;
            }

            contentWidget = Row(
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
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight:
                          isTargetMessage ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }
          break;
        }
      case 'text':
      default:
        {
          contentWidget = Text(
            content,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isTargetMessage ? FontWeight.bold : FontWeight.normal,
            ),
          );
          break;
        }
    }
    return contentWidget;
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * MESSAGE_BOX_MAX_SIZE;
    final count = widget.messages.length;
    return ListView.builder(
      reverse: true,
      physics: ClampingScrollPhysics(),
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: count + 1,
      itemBuilder: (context, index) {
        if (index == count) {
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

        final message = widget.messages[index];
        final isMe = message['sender_id'] == widget.myId;
        final showTimestamp = showTimestampIndices.contains(index);
        final showAvatar = !isMe && isLastInSequence(index);
        final statuses = message['message_statuses'] as List<dynamic>;

        bool isHidden = false;
        if (statuses.isNotEmpty) {
          final myStatus = statuses.firstWhere(
            (status) => status['user_id'] == widget.myId,
            orElse: () => {'is_hidden': false},
          );
          isHidden = myStatus['is_hidden'] == true;
        }

        bool isReadByAll = false;
        if (isMe && statuses.isNotEmpty) {
          isReadByAll = statuses.every(
            (status) =>
                status['user_id'] == widget.myId || status['is_read'] == true,
          );
        }
        return GestureDetector(
          onLongPress: !isHidden ? () => widget.onMessageHold(index) : null,
          onTap: () => toggleTimestamp(index),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                      isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showAvatar) ...[
                      CircleAvatar(
                        backgroundImage:
                            widget.friendImage.isNotEmpty
                                ? CachedNetworkImageProvider(widget.friendImage)
                                : null,
                        radius: 16,
                      ),
                      const SizedBox(width: 5),
                    ] else if (!isMe) ...[
                      const SizedBox(width: 37),
                    ],
                    Flexible(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child:
                            isHidden
                                ? Text(
                                  'Tin nhắn đã bị xóa',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14,
                                  ),
                                )
                                : buildMessageContent(
                                  context,
                                  message,
                                  widget.targetMessageId,
                                ),
                      ),
                    ),
                    if (isMe) const SizedBox(width: 10),
                  ],
                ),
                const SizedBox(height: 5),
                if (showTimestamp)
                  Padding(
                    padding: EdgeInsets.only(
                      right: isMe ? 10 : 0,
                      left: !isMe ? 41 : 0,
                    ),
                    child: Text(
                      formatTimestamp(message['sent_at']),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                if (isMe && index == 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          !isReadByAll
                              ? FontAwesomeIcons.circleCheck
                              : FontAwesomeIcons.solidCircleCheck,
                          size: 14,
                          color: !isReadByAll ? Colors.grey : Colors.blue,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          !isReadByAll ? 'Đã gửi' : 'Đã xem',
                          style: TextStyle(
                            fontSize: 12,
                            color: !isReadByAll ? Colors.grey : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
