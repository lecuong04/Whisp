import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:whisp/presentation/widgets/message_block.dart';
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
    required this.onMessageTap,
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
      return true; // Tin nhắn cuối cùng trong danh sách
    }
    final currentMessage = widget.messages[index];
    final nextMessage = widget.messages[index + 1];
    return currentMessage['sender_id'] != nextMessage['sender_id'];
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * MESSAGE_BOX_MAX_SIZE;
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
        final showTimestamp = showTimestampIndices.contains(messageIndex);
        final messageType = message['message_type'] as String;
        final showAvatar = !isMe && isLastInSequence(messageIndex);

        // Kiểm tra trạng thái is_hidden cho người dùng hiện tại
        bool isHidden = false;
        if (message['message_statuses'] != null) {
          final statuses = message['message_statuses'] as List<dynamic>;
          final myStatus = statuses.firstWhere(
            (status) => status['user_id'] == widget.myId,
            orElse: () => {'is_hidden': false},
          );
          isHidden = myStatus['is_hidden'] == true;
        }

        // Tính trạng thái đã đọc
        bool isReadByAll = false;
        if (isMe && message['message_statuses'] != null) {
          final statuses = message['message_statuses'] as List<dynamic>;
          isReadByAll = statuses.every(
            (status) =>
                status['user_id'] == widget.myId || status['is_read'] == true,
          );
        }

        return GestureDetector(
          onLongPress:
              !isHidden
                  ? () {
                    widget.onMessageTap(messageIndex);
                  }
                  : null,
          onTap: () {
            toggleTimestamp(messageIndex);
          },
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
                                ? NetworkImage(widget.friendImage)
                                : null,
                        radius: 18,
                      ),
                      const SizedBox(width: 5),
                    ] else if (!isMe) ...[
                      const SizedBox(
                        width: 25,
                      ), // Giữ khoảng cách tương ứng khi không hiển thị avatar
                    ],
                    Flexible(
                      child:
                          isHidden
                              ? Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7,
                                ),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      isMe
                                          ? Colors.blue[100]
                                          : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Tin nhắn đã bị xóa',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                              : Container(
                                padding:
                                    messageType == "text"
                                        ? const EdgeInsets.all(10)
                                        : null,
                                decoration: BoxDecoration(
                                  color:
                                      isMe
                                          ? Colors.blue[100]
                                          : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: MessageBlock(
                                  key: ValueKey(message['id']),
                                  message: message,
                                  targetMessageId: widget.targetMessageId,
                                  maxWidth: maxWidth,
                                  scrollController: widget.scrollController,
                                  context: context,
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
                if (isMe && messageIndex == widget.messages.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Row(
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
                  ),
              ],
            ),
          ),
        );
      },
    );
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
}
