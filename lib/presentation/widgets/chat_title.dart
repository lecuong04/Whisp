import 'package:flutter/material.dart';
import 'package:whisp/utilities.dart';

class ChatTitle extends StatefulWidget {
  final String avatarUrl;
  final String fullName;
  final DateTime time;
  final bool isSeen;
  final bool isOnline;
  final String lastMessage;
  final VoidCallback? onTap;

  const ChatTitle(
    this.avatarUrl,
    this.fullName,
    this.time,
    this.isSeen,
    this.isOnline,
    this.lastMessage, {
    this.onTap,
    super.key,
  });

  @override
  State<StatefulWidget> createState() {
    return _ChatTitleState();
  }
}

class _ChatTitleState extends State<ChatTitle> {
  @override
  Widget build(BuildContext context) {
    bool is24HourFormat = MediaQuery.of(context).alwaysUse24HourFormat;
    print('ChatTitle time: ${widget.time}');
    return ListTile(
      // Xóa Column và Divider
      onTap: widget.onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              widget.fullName,
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    (!widget.isSeen ? FontWeight.bold : FontWeight.normal),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                dateTimeFormat(widget.time, is24HourFormat),
                style: TextStyle(
                  fontWeight:
                      (!widget.isSeen ? FontWeight.bold : FontWeight.normal),
                ),
              ),
              const Padding(padding: EdgeInsets.only(right: 2)),
              const Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),
        ],
      ),
      leading: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          alignment: AlignmentDirectional.center,
          children: [
            CircleAvatar(
              backgroundImage:
                  widget.avatarUrl.isNotEmpty
                      ? NetworkImage(widget.avatarUrl)
                      : null,
              radius: 26,
            ),
            if (widget.isOnline) ...[
              Align(
                alignment: Alignment.bottomRight,
                child: Stack(
                  alignment: AlignmentDirectional.center,
                  children: const [
                    Icon(Icons.circle, color: Colors.white, size: 18),
                    Icon(Icons.circle, color: Colors.green, size: 14),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      horizontalTitleGap: 8,
      subtitle: Text(
        widget.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: (!widget.isSeen ? FontWeight.w700 : FontWeight.normal),
          fontSize: 16,
          color: (!widget.isSeen ? Colors.black : Colors.black87),
        ),
      ),
    );
  }
}
