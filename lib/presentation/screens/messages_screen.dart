import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:whisp/services/chat_service.dart';
import 'package:whisp/presentation/widgets/message_list.dart';
import 'package:whisp/presentation/widgets/message_input.dart';
import 'package:whisp/services/user_service.dart';
import 'package:whisp/utils/constants.dart'; // Import constants.dart

class MessagesScreen extends StatefulWidget {
  final String chatId;
  final String contactName;
  final String contactImage;

  const MessagesScreen({
    super.key,
    required this.chatId,
    required this.contactName,
    required this.contactImage,
  });

  @override
  State createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String myId = UserService().id!;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _allMessages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isAtBottom = true;
  bool _hasNewMessage = false;
  bool _hasMoreMessages = true;
  String? _error;
  final Set<int> _selectedMessages = {};

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

    if (currentScroll <= 100 && _hasMoreMessages && !_isLoadingMore) {
      _loadMoreMessages();
    }
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
      _chatService.markMessagesAsRead(widget.chatId).catchError((e) {
        print('Cảnh báo: Không thể đánh dấu tin nhắn đã đọc: $e');
      });

      final messages = await _chatService.loadMessages(
        widget.chatId,
        limit: MESSAGE_PAGE_SIZE,
      );
      setState(() {
        _allMessages = messages.reversed.toList();
        _isLoading = false;
        _hasMoreMessages = messages.length == MESSAGE_PAGE_SIZE;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      _chatService.subscribeToMessages(widget.chatId, (updatedMessages) {
        final newMessages =
            updatedMessages.where((newMsg) {
              return !_allMessages.any(
                (oldMsg) => oldMsg['id'] == newMsg['id'],
              );
            }).toList();

        if (newMessages.isNotEmpty) {
          _allMessages.addAll(newMessages);
          _allMessages.sort((a, b) {
            final aTime = DateTime.parse(a['sent_at']);
            final bTime = DateTime.parse(b['sent_at']);
            return aTime.compareTo(bTime);
          });

          if (newMessages.any((msg) => msg['sender_id'] != myId)) {
            _chatService.markMessagesAsRead(widget.chatId).catchError((e) {
              print('Cảnh báo: Không thể đánh dấu tin nhắn đã đọc: $e');
            });
          }

          if (_isAtBottom) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          } else {
            _hasNewMessage = true;
          }
        }
        setState(() {});
      });
    } catch (e) {
      _error = "Lỗi khi tải tin nhắn: $e";
      _isLoading = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (!_hasMoreMessages || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final oldestMessage = _allMessages.first;
      final beforeSentAt = oldestMessage['sent_at'];
      final olderMessages = await _chatService.loadMessages(
        widget.chatId,
        limit: MESSAGE_PAGE_SIZE,
        beforeSentAt: beforeSentAt,
      );

      if (olderMessages.isNotEmpty) {
        setState(() {
          final newMessages =
              olderMessages.where((newMsg) {
                return !_allMessages.any(
                  (oldMsg) => oldMsg['id'] == newMsg['id'],
                );
              }).toList();
          _allMessages.insertAll(0, newMessages.reversed);
          _isLoadingMore = false;
          _hasMoreMessages = olderMessages.length == MESSAGE_PAGE_SIZE;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
          _hasMoreMessages = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Lỗi khi tải thêm tin nhắn: $e";
        _isLoadingMore = false;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi tải thêm tin nhắn')));
      });
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      final newMessage = await _chatService.sendMessage(
        conversationId: widget.chatId,
        senderId: myId,
        content: _messageController.text,
      );

      setState(() {
        _allMessages.add(newMessage);
        _allMessages.sort((a, b) {
          final aTime = DateTime.parse(a['sent_at']);
          final bTime = DateTime.parse(b['sent_at']);
          return aTime.compareTo(bTime);
        });
      });

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi gửi tin nhắn: $e')));
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
              backgroundImage:
                  widget.contactImage.isNotEmpty
                      ? NetworkImage(widget.contactImage)
                      : null,
              radius: 20,
            ),
            const SizedBox(width: 10),
            Text(widget.contactName),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context, {'conversation_id': widget.chatId});
          },
          icon: const Icon(FontAwesomeIcons.chevronLeft),
        ),
        actions: [
          IconButton(
            onPressed: () {},
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
                    _isLoading && _allMessages.isEmpty
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
                          myId: myId,
                          friendImage: widget.contactImage,
                          scrollController: _scrollController,
                          isLoadingMore: _isLoadingMore,
                          hasMoreMessages: _hasMoreMessages,
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
    _chatService.unsubscribeMessages();
    super.dispose();
  }
}
