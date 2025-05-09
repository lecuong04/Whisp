import 'package:flutter/material.dart';
import 'package:whisp/models/friend_request.dart';
import 'package:whisp/presentation/screens/messages_screen.dart';
import 'package:whisp/services/chat_service.dart';
import 'package:whisp/services/user_service.dart';

class FriendRequestTitle extends StatefulWidget {
  final FriendRequest request;

  const FriendRequestTitle({required this.request, super.key});

  @override
  State<StatefulWidget> createState() => _FriendRequestTitleState();
}

class _FriendRequestTitleState extends State<FriendRequestTitle> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () async {
        var req = widget.request;
        var userId = await UserService().getIdFromUsername(req.username);
        if (userId.isNotEmpty) {
          var chatId = await ChatService().getDirectConversation(userId);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => MessagesScreen(
                    conversationId: chatId,
                    conversationName: req.fullName,
                    conversationAvatar: req.avatarURL,
                  ),
            ),
          );
        } else {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text("Thông báo", textAlign: TextAlign.center),
                  content: Text(
                    "Người dùng này không muốn nhận tin nhắn từ người lạ!",
                  ),
                ),
          );
        }
      },
      leading: CircleAvatar(
        radius: 24,
        backgroundImage:
            widget.request.avatarURL.isNotEmpty
                ? NetworkImage(widget.request.avatarURL)
                : null,
      ),
      title: Text(
        widget.request.fullName,
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        "@${widget.request.username}",
        style: TextStyle(color: Colors.grey),
      ),
      trailing: Wrap(
        spacing: 5,
        children: [
          if (widget.request.status == "pending" &&
              !widget.request.isYourRequest) ...[
            GestureDetector(
              onTap: () async {
                await widget.request.rejectFriend();
                setState(() {});
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey),
                ),
                child: Icon(Icons.close),
              ),
            ),
          ],
          GestureDetector(
            onTap: () async {
              await widget.request.requestFriend();
              setState(() {});
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey),
              ),
              child: Icon(_getStatus()),
            ),
          ),
        ],
      ),
    );
  }

  IconData? _getStatus() {
    String s = widget.request.status;
    if (s == "" || s == "rejected") {
      return Icons.add;
    } else if (s == "pending") {
      if (widget.request.isYourRequest) {
        return Icons.send;
      } else {
        return Icons.done;
      }
    } else if (s == 'accepted') {
      return Icons.person;
    } else {
      return Icons.send;
    }
  }
}
