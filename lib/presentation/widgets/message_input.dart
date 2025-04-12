import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

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

  // Chọn ảnh từ thư viện hoặc camera
  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await showModalBottomSheet<XFile?>(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Chụp ảnh'),
                onTap: () async {
                  final file = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  Navigator.pop(context, file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Chọn từ thư viện'),
                onTap: () async {
                  final file = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  Navigator.pop(context, file);
                },
              ),
            ],
          ),
    );

    if (pickedFile != null) {
      onSendMedia('image:${pickedFile.path}');
    }
  }

  // Chọn video từ thư viện hoặc quay video mới
  Future<void> _pickVideo(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await showModalBottomSheet<XFile?>(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Quay video'),
                onTap: () async {
                  final file = await picker.pickVideo(
                    source: ImageSource.camera,
                  );
                  Navigator.pop(context, file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Chọn từ thư viện'),
                onTap: () async {
                  final file = await picker.pickVideo(
                    source: ImageSource.gallery,
                  );
                  Navigator.pop(context, file);
                },
              ),
            ],
          ),
    );

    if (pickedFile != null) {
      onSendMedia('video:${pickedFile.path}');
    }
  }

  // Chọn file từ thiết bị
  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      if (file.path != null) {
        onSendMedia('file:${file.path}:${file.name}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.blue),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder:
                    (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.image),
                          title: const Text('Gửi ảnh'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(context);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.videocam),
                          title: const Text('Gửi video'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickVideo(context);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: const Text('Gửi file'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickFile(context);
                          },
                        ),
                      ],
                    ),
              );
            },
          ),
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
            icon: const Icon(Icons.send, color: Colors.blue),
          ),
        ],
      ),
    );
  }
}
