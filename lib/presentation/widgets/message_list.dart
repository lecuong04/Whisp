import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  MessageListState createState() => MessageListState();
}

class MessageListState extends State<MessageList> {
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

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: widget.messages.length + (widget.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.messages.length && widget.isLoadingMore) {
          return const Center(child: CircularProgressIndicator());
        }

        final message = widget.messages[index];
        final isMe = message['sender_id'] == widget.myId;
        final isSelected = widget.selectedMessages.contains(index);
        final showTimestamp = _showTimestampIndices.contains(index);

        // Kiểm tra trạng thái đã xem cho tin nhắn từ tôi
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
            _toggleTimestamp(index); // Bật/tắt thời gian
            widget.onMessageTap(index); // Giữ logic chọn tin nhắn
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
                    backgroundImage: NetworkImage(widget.friendImage),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          border:
                              isSelected
                                  ? Border.all(color: Colors.blue, width: 2)
                                  : null,
                        ),
                        child: Text(
                          message['content'],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (showTimestamp) // Chỉ hiển thị nếu nhấp
                        Text(
                          _formatTimestamp(message['sent_at']),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      if (isMe && index == widget.messages.length - 1)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isReadByAll
                                  ? FontAwesomeIcons.checkDouble
                                  : FontAwesomeIcons.check,
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
