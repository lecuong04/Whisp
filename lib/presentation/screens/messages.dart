import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/services/chat_service.dart';
import 'package:whisp/presentation/widgets/message_list.dart';
import 'package:whisp/presentation/widgets/message_input.dart';

class Messages extends StatefulWidget {
  final String chatId;
  final String myId;
  final String friendId;
  final String friendName;
  final String friendImage;

  const Messages({
    super.key,
    required this.chatId,
    required this.myId,
    required this.friendId,
    required this.friendName,
    required this.friendImage,
  });

  @override
  MessagesState createState() => MessagesState();
}

class MessagesState extends State<Messages> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _allMessages = [];
  bool _isLoading = true;
  bool _isAtBottom = true;
  bool _hasNewMessage = false;
  String? _error;
  Set<int> _selectedMessages = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _initializeMessages();
  }

  void _scrollListener() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const threshold = 100.0;

    setState(() {
      _isAtBottom = (maxScroll - currentScroll) <= threshold;
      if (_isAtBottom) {
        _hasNewMessage = false;
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        _isAtBottom = true;
        _hasNewMessage = false;
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  Future<void> _initializeMessages() async {
    try {
      // Gọi markMessagesAsRead bất đồng bộ
      _chatService.markMessagesAsRead(widget.chatId).catchError((e) {
        print('Cảnh báo: Không thể đánh dấu tin nhắn đã đọc: $e');
        // Không đặt _error để tránh hiển thị lỗi giao diện
      });

      // Tải tin nhắn
      final messages = await _chatService.loadMessages(widget.chatId);
      setState(() {
        _allMessages = messages;
        _isLoading = false;
      });

      // Cuộn xuống dưới
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      // Theo dõi tin nhắn mới qua Realtime
      _chatService.subscribeToMessages(widget.chatId, (updatedMessages) {
        setState(() {
          final newMessages =
              updatedMessages.where((newMsg) {
                return !_allMessages.any(
                  (oldMsg) => oldMsg['id'] == newMsg['id'],
                );
              }).toList();

          _allMessages.addAll(newMessages);

          _allMessages.sort((a, b) {
            final aTime = DateTime.parse(a['sent_at']);
            final bTime = DateTime.parse(b['sent_at']);
            return aTime.compareTo(bTime);
          });

          if (newMessages.isNotEmpty) {
            if (_isAtBottom) {
              _scrollToBottom();
            } else {
              _hasNewMessage = true;
            }
          }
        });
      });
    } catch (e) {
      setState(() {
        _error = "Lỗi khi tải tin nhắn: $e";
        _isLoading = false;
      });
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      final newMessage = await _chatService.sendMessage(
        conversationId: widget.chatId,
        senderId: widget.myId,
        content: _messageController.text,
      );

      setState(() {
        _allMessages.add(newMessage);
      });

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = "Lỗi khi gửi tin nhắn: $e";
      });
    }
  }

  void _onMessageTap(int index) {
    setState(() {
      if (_selectedMessages.contains(index)) {
        _selectedMessages.remove(index);
      } else {
        _selectedMessages.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.friendImage),
              radius: 20,
            ),
            const SizedBox(width: 10),
            Text(widget.friendName),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            // Trả về conversation_id để Chats cập nhật local
            Navigator.pop(context, {'conversation_id': widget.chatId});
          },
          icon: const Icon(FontAwesomeIcons.chevronLeft),
        ),
        actions: [
          IconButton(
            onPressed: () {}, // Có thể thêm chức năng gọi video sau
            icon: const Icon(FontAwesomeIcons.video),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                        ? Center(
                          child: Text(
                            "Lỗi: $_error",
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                        : _allMessages.isEmpty
                        ? const Center(child: Text("Chưa có tin nhắn nào"))
                        : MessageList(
                          messages: _allMessages,
                          myId: widget.myId,
                          friendImage: widget.friendImage,
                          scrollController: _scrollController,
                          isLoadingMore: false,
                          hasMoreMessages: false,
                          selectedMessages: _selectedMessages,
                          onMessageTap: _onMessageTap,
                        ),
              ),
              MessageInput(
                controller: _messageController,
                onSend: _sendMessage,
                onTextFieldTap: () {},
              ),
            ],
          ),
          if (_hasNewMessage)
            Positioned(
              bottom: 80,
              right: 20,
              child: FloatingActionButton(
                onPressed: _scrollToBottom,
                child: const Icon(Icons.arrow_downward),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    Supabase.instance.client.channel('public:messages').unsubscribe();
    super.dispose();
  }
}
