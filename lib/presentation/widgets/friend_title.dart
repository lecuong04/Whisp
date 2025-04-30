import 'package:flutter/material.dart';
import 'package:whisp/models/friend.dart';
import 'package:whisp/presentation/screens/messages_screen.dart';
import 'package:whisp/services/chat_service.dart';

class FriendTitle extends StatelessWidget {
  final Friend friend;
  final GestureLongPressCallback? onLongPress;
  const FriendTitle({required this.friend, super.key, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onLongPress: onLongPress,
          onTap: () async {
            var chatId = await ChatService().getDirectConversation(friend.id);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) {
                  return MessagesScreen(
                    chatId: chatId,
                    contactName: friend.fullName,
                    contactImage: friend.avatarUrl,
                  );
                },
              ),
            );
          },
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
          leading: SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                CircleAvatar(
                  backgroundImage:
                      friend.avatarUrl.isNotEmpty
                          ? NetworkImage(friend.avatarUrl)
                          : null,
                  radius: 26,
                ),
                if (friend.isOnline) ...[
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Stack(
                      alignment: AlignmentDirectional.center,
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 18),
                        Icon(Icons.circle, color: Colors.green, size: 14),
                      ],
                    ),
                  ),
                ] else
                  ...[],
              ],
            ),
          ),
          title: Text(friend.fullName, style: TextStyle(fontSize: 18)),
          subtitle: Text("@${friend.username}"),
        ),
        Padding(padding: EdgeInsets.only(bottom: 8)),
      ],
    );
  }
}
