import 'package:flutter/material.dart';
import 'package:whisp/models/friend_request.dart';

class FriendRequestTitle extends StatefulWidget {
  final FriendRequest request;

  const FriendRequestTitle({required this.request, super.key});

  @override
  State<StatefulWidget> createState() => FriendRequestTitleState();
}

class FriendRequestTitleState extends State<FriendRequestTitle> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(widget.request.avatarURL ?? ""),
      ),
      title: Text(
        widget.request.fullName,
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        "@${widget.request.username}",
        style: TextStyle(color: Colors.grey),
      ),
      trailing: GestureDetector(
        onTap: () {},
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color:
                widget.request.status == ""
                    ? Colors.grey[100]
                    : widget.request.status == "pending"
                    ? Theme.of(context).primaryColor
                    : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey),
          ),
          child: Text(
            widget.request.status == ""
                ? 'Kết bạn'
                : widget.request.status == "pending"
                ? 'Đã gửi'
                : "Đã kết bạn",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
