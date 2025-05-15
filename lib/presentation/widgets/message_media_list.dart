import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:whisp/custom_cache_manager.dart';

class MessageMediaList extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  final String myId;

  const MessageMediaList({
    super.key,
    required this.messages,
    required this.myId,
  });

  @override
  State<MessageMediaList> createState() => _MessageMediaListState();
}

class _MessageMediaListState extends State<MessageMediaList>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'Tất cả'; // Mặc định là "Tất cả"
  late TabController _tabController;

  final List<String> _filters = ['Tất cả', 'File', 'Ảnh/Video'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (mounted) {
        setState(() {
          _selectedFilter = _filters[_tabController.index];
        });
      }
    });
  }

  // Lọc danh sách tin nhắn dựa trên bộ lọc
  List<Map<String, dynamic>> _getFilteredMessages() {
    return widget.messages.where((message) {
      final messageType = message['message_type'] as String;
      final statuses = message['message_statuses'] as List<dynamic>;
      final isHidden = statuses.any(
        (status) =>
            status['user_id'] == widget.myId && status['is_hidden'] == true,
      );
      if (isHidden) return false;
      switch (_selectedFilter) {
        case 'Tất cả':
          return messageType == 'image' ||
              messageType == 'video' ||
              messageType == 'file';
        case 'File':
          return messageType == 'file';
        case 'Ảnh/Video':
          return messageType == 'image' || messageType == 'video';
        default:
          return false;
      }
    }).toList();
  }

  // Widget hiển thị nội dung media
  Widget _buildMediaItem(Map<String, dynamic> message) {
    final messageType = message['message_type'] as String;
    final content = message['content'] as String;
    final senderId = message['sender_id'] as String;
    final senderName = (message['users']?['full_name'] as String?) ?? 'Unknown';
    final sentAt = DateTime.parse(message['sent_at']).toLocal();
    final isMe = senderId == widget.myId;

    Widget contentWidget;
    switch (messageType) {
      case 'image':
        contentWidget = CachedNetworkImage(
          imageUrl: content,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          placeholder:
              (context, url) => const SizedBox(
                width: 60,
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              ),
          errorWidget: (context, url, error) => const Icon(Icons.error),
          cacheManager: CustomCacheManager(),
        );
        break;
      case 'video':
        contentWidget = const Icon(
          Icons.videocam,
          size: 60,
          color: Colors.blue,
        );
        break;
      case 'file':
        contentWidget = const Icon(
          Icons.insert_drive_file,
          size: 60,
          color: Colors.blue,
        );
        break;
      default:
        contentWidget = const SizedBox.shrink();
    }

    return ListTile(
      leading: contentWidget,
      title: Text(
        messageType == 'file' ? content.split('/').last : senderName,
        style: TextStyle(
          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        '${sentAt.day}/${sentAt.month}/${sentAt.year} ${sentAt.hour}:${sentAt.minute.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      onTap: () {
        // Để trống vì chỉ yêu cầu UI
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width:
          MediaQuery.of(
            context,
          ).size.width, // Chiếm toàn bộ chiều rộng màn hình
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop(); // Đóng drawer với hiệu ứng trượt
            },
          ),
          title: const Row(
            children: [
              // Icon(Icons.attachment),
              // SizedBox(width: 10),
              Text('Ảnh/Video, file', style: TextStyle(fontSize: 20)),
            ],
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelStyle: const TextStyle(
                // fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 16,
              ),
              indicatorColor: Colors.black,
              indicatorWeight: 3,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              tabs: _filters.map((filter) => Tab(text: filter)).toList(),
            ),
            Expanded(
              child:
                  _getFilteredMessages().isEmpty
                      ? const Center(
                        child: Text(
                          'Không có media nào',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _getFilteredMessages().length,
                        itemBuilder: (context, index) {
                          final message = _getFilteredMessages()[index];
                          return _buildMediaItem(message);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
