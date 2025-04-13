import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    double maxWidth = MediaQuery.of(context).size.width * (2 / 3);

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.all(10),
      itemCount: messages.length + (isLoadingMore ? 1 : 0) + (hasMoreMessages ? 0 : 1),
      itemBuilder: (context, index) {
        if (!hasMoreMessages && index == 0) {
          return Center(child: Text("Đã load hết tin nhắn"));
        }

        if (isLoadingMore && index == 0) {
          return Center(child: CircularProgressIndicator());
        }

        final adjustedIndex = isLoadingMore ? index - 1 : index;
        if (adjustedIndex < 0) return SizedBox.shrink();

        final message = messages[adjustedIndex];
        bool isMe = message['sender_id'] == myId;
        bool isSelected = selectedMessages.contains(adjustedIndex);

        bool showAvatar = !isMe && (adjustedIndex == 0 || messages[adjustedIndex]['sender_id'] != messages[adjustedIndex - 1]['sender_id']);

        return GestureDetector(
          onTap: () => onMessageTap(adjustedIndex),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) Padding(padding: const EdgeInsets.only(top: 6, right: 8.0), child: showAvatar ? CircleAvatar(backgroundImage: NetworkImage(friendImage), radius: 12) : SizedBox(width: 25)),
              Expanded(
                child: Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(color: isMe ? Colors.blue : Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (message['text'] != null) Text(message['text'], style: TextStyle(color: isMe ? Colors.white : Colors.black))]),
                      ),
                      if (isSelected && message['timestamp'] != null)
                        Padding(padding: const EdgeInsets.only(left: 10, right: 10), child: Text(DateFormat('HH:mm').format(DateTime.parse(message['timestamp'])), style: TextStyle(fontSize: 12, color: Colors.grey))),
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
