import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onTextFieldTap;
  final Function(File, String) onMediaSelected;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onTextFieldTap,
    required this.onMediaSelected,
  });

  @override
  State createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput>
    with WidgetsBindingObserver {
  bool hasText = false;
  OverlayEntry? mediaOverlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(updateTextState);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(updateTextState);
    removeOverlay();
    super.dispose();
  }

  void updateTextState() {
    setState(() {
      hasText = widget.controller.text.trim().isNotEmpty;
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = View.of(context).viewInsets.bottom;
    if (bottomInset == 0 && mediaOverlay != null) {
      removeOverlay();
    }
  }

  void removeOverlay() {
    mediaOverlay?.remove();
    mediaOverlay = null;
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      widget.onMediaSelected(File(pickedFile.path), 'image');
    }
    removeOverlay();
  }

  Future<void> captureImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      widget.onMediaSelected(File(pickedFile.path), 'image');
    }
    removeOverlay();
  }

  Future<void> pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      widget.onMediaSelected(File(pickedFile.path), 'video');
    }
    removeOverlay();
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      widget.onMediaSelected(File(result.files.single.path!), 'file');
    }
    removeOverlay();
  }

  Future<void> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      widget.onMediaSelected(File(result.files.single.path!), 'audio');
    }
    removeOverlay();
  }

  void showMediaOptions(BuildContext context, GlobalKey key) {
    if (mediaOverlay != null) return;

    final RenderBox button =
        key.currentContext!.findRenderObject() as RenderBox;
    final position = button.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;
    final modalWidth = screenWidth * 0.6;
    const modalHeight = 160.0;

    mediaOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  removeOverlay();
                },
                behavior: HitTestBehavior.translucent,
                child: Container(),
              ),
            ),
            Positioned(
              left: 12,
              top: position.dy - modalHeight - 20,
              width: modalWidth,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildOptionRow(
                      title: 'Chụp ảnh',
                      icon: Icons.camera_alt,
                      onTap: captureImage,
                      showDivider: true,
                    ),
                    buildOptionRow(
                      title: 'Chọn ảnh',
                      icon: Icons.image,
                      onTap: pickImage,
                      showDivider: true,
                    ),
                    buildOptionRow(
                      title: 'Chọn audio',
                      icon: Icons.audio_file_outlined,
                      onTap: pickAudio,
                      showDivider: true,
                    ),
                    buildOptionRow(
                      title: 'Chọn video',
                      icon: Icons.videocam,
                      onTap: pickVideo,
                      showDivider: true,
                    ),
                    buildOptionRow(
                      title: 'Chọn file',
                      icon: Icons.attach_file,
                      onTap: pickFile,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(mediaOverlay!);
  }

  Widget buildOptionRow({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool showDivider,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 15)),
                Icon(icon, color: Colors.blue, size: 20),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Colors.grey),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey plusButtonKey = GlobalKey();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.white,
      child: Row(
        children: [
          InkWell(
            key: plusButtonKey,
            onTap: () => showMediaOptions(context, plusButtonKey),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      decoration: const InputDecoration(
                        hintText: "Aa",
                        border: InputBorder.none,
                      ),
                      onTap: widget.onTextFieldTap,
                    ),
                  ),
                  const Icon(Icons.emoji_emotions_rounded, color: Colors.blue),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: hasText ? widget.onSend : null,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasText ? Colors.blueAccent : Colors.grey[400],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
