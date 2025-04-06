import 'package:flutter/material.dart';
import 'package:whisp/utilities.dart';
import 'package:material_symbols_icons/symbols.dart';

class ChatTitle extends StatefulWidget {
  final String alias;
  final DateTime time;
  final bool isSeen;
  final String urlImg;
  final bool isOnline;
  final String lastMessage; // Thêm tham số lastMessage
  final VoidCallback? onTap;

  const ChatTitle(
    this.urlImg,
    this.alias,
    this.time,
    this.isSeen,
    this.isOnline,
    this.lastMessage, { // Thêm vào constructor
    this.onTap,
    super.key,
  });

  @override
  State<StatefulWidget> createState() {
    return ChatTitleState();
  }
}

class ChatTitleState extends State<ChatTitle> {
  @override
  Widget build(BuildContext context) {
    bool is24HourFormat = MediaQuery.of(context).alwaysUse24HourFormat;
    return Column(
      children: [
        ListTile(
          onTap: widget.onTap,
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  widget.alias,
                  style: TextStyle(fontSize: 20, fontWeight: (!widget.isSeen ? FontWeight.bold : FontWeight.normal)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    dateTimeFormat(widget.time, is24HourFormat),
                    style: TextStyle(fontWeight: (!widget.isSeen ? FontWeight.bold : FontWeight.normal)),
                  ),
                  Padding(padding: EdgeInsets.only(right: 2)),
                  Icon(Symbols.arrow_forward_ios, size: 18),
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
                CircleAvatar(backgroundImage: NetworkImage(widget.urlImg), radius: 26),
                if (widget.isOnline) ...[
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
          horizontalTitleGap: 8,
          subtitle: Text(
            widget.lastMessage, // Sử dụng lastMessage thay vì giá trị tĩnh
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: (!widget.isSeen ? FontWeight.w700 : FontWeight.normal),
              fontSize: 16,
              color: (!widget.isSeen ? Colors.black : Colors.black87),
            ),
          ),
        ),
        Divider(height: 8),
      ],
    );
  }
}
