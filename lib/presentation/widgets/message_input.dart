import 'package:flutter/material.dart';

class MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final Function() onSend;
  final Function(String) onSendMedia;
  final Function() onTextFieldTap;

  const MessageInput({
    Key? key,
    required this.controller,
    required this.onSend,
    required this.onSendMedia,
    required this.onTextFieldTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: "Nhập tin nhắn...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onTap: onTextFieldTap,
            ),
          ),
          IconButton(
            onPressed: onSend,
            icon: Icon(Icons.send, color: Colors.blue),
          ),
        ],
      ),
    );
  }
}
