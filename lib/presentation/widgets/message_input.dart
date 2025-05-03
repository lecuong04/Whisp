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
  _MessageInputState createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput>
    with WidgetsBindingObserver {
  bool hasText = false;
  OverlayEntry? _mediaOverlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_updateTextState);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_updateTextState);
    _removeOverlay();
    super.dispose();
  }

  void _updateTextState() {
    setState(() {
      hasText = widget.controller.text.trim().isNotEmpty;
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    if (bottomInset == 0 && _mediaOverlay != null) {
      _removeOverlay();
    }
  }

  void _removeOverlay() {
    _mediaOverlay?.remove();
    _mediaOverlay = null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      widget.onMediaSelected(File(pickedFile.path), 'image');
    }
    _removeOverlay();
  }

  Future<void> _captureImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      widget.onMediaSelected(File(pickedFile.path), 'image');
    }
    _removeOverlay();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      widget.onMediaSelected(File(pickedFile.path), 'video');
    }
    _removeOverlay();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      widget.onMediaSelected(File(result.files.single.path!), 'file');
    }
    _removeOverlay();
  }

  void _showMediaOptions(BuildContext context, GlobalKey key) {
    if (_mediaOverlay != null) return;

    final RenderBox button =
        key.currentContext!.findRenderObject() as RenderBox;
    final position = button.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;
    final modalWidth = screenWidth * 0.6;
    const modalHeight = 160.0;

    _mediaOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  _removeOverlay();
                },
                behavior: HitTestBehavior.translucent,
                child: Container(),
              ),
            ),
            Positioned(
              left: 0,
              top: position.dy - modalHeight - 8,
              width: modalWidth,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildOptionRow(
                      title: 'Chụp ảnh',
                      icon: Icons.camera_alt,
                      onTap: _captureImage,
                      showDivider: true,
                    ),
                    _buildOptionRow(
                      title: 'Chọn ảnh',
                      icon: Icons.image,
                      onTap: _pickImage,
                      showDivider: true,
                    ),
                    _buildOptionRow(
                      title: 'Chọn video',
                      icon: Icons.videocam,
                      onTap: _pickVideo,
                      showDivider: true,
                    ),
                    _buildOptionRow(
                      title: 'Chọn file',
                      icon: Icons.attach_file,
                      onTap: _pickFile,
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

    Overlay.of(context).insert(_mediaOverlay!);
  }

  Widget _buildOptionRow({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool showDivider,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
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
            onTap: () => _showMediaOptions(context, plusButtonKey),
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
