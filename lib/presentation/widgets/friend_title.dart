import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:whisp/models/call_manager.dart';
import 'package:whisp/models/friend.dart';
import 'package:whisp/presentation/screens/messages_screen.dart';
import 'package:whisp/presentation/screens/video_call_screen.dart';
import 'package:whisp/services/call_service.dart';
import 'package:whisp/services/chat_service.dart';

class FriendTitle extends StatelessWidget {
  final Friend friend;
  final GestureLongPressCallback? onLongPress;
  const FriendTitle({required this.friend, super.key, this.onLongPress});

  static Future<void> _makeCall(
    BuildContext context,
    String friendId,
    bool videoEnabled,
  ) async {
    CallManager callManager = CallManager.instance;
    if (callManager.service != null &&
        callManager.service?.isConnectionEstablished == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cuộc gọi hiện tại chưa kết thúc!')),
      );
      return;
    }
    var data = await CallService().makeCallRequest(friendId, 30, videoEnabled);
    if (data != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(callInfo: data),
        ),
      );
    }
  }

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
                          ? CachedNetworkImageProvider(friend.avatarUrl)
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
          trailing: Wrap(
            children: [
              IconButton(
                onPressed: () async {
                  await _makeCall(context, friend.id, true);
                },
                icon: Icon(Icons.videocam),
              ),
              IconButton(
                onPressed: () async {
                  await _makeCall(context, friend.id, false);
                },
                icon: Icon(Icons.call),
              ),
            ],
          ),
        ),
        Padding(padding: EdgeInsets.only(bottom: 8)),
      ],
    );
  }
}
