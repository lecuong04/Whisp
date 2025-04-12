import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:whisp/services/chat_service.dart';
import '../widgets/message_list.dart';
import '../widgets/message_input.dart';

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
  List<Map<String, dynamic>> _allMessages = [];
  Set<int> _selectedMessages = {};
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  Map<String, dynamic>? _firstMessage;
  bool _isFirstLoad = true;
  bool _isAtBottom = true;
  bool _hasNewMessage = false;
  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _markMessagesAsReceived();
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

    if (_scrollController.position.pixels ==
            _scrollController.position.minScrollExtent &&
        !_isLoadingMore &&
        _hasMoreMessages) {
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
      _isAtBottom = true;
      _hasNewMessage = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _markMessagesAsReceived() async {
    await _chatService.markMessagesAsReceived(widget.chatId, widget.myId);
  }

  void _loadMoreMessages() async {
    if (_firstMessage == null || !_hasMoreMessages) return;

    setState(() {
      _isLoadingMore = true;
    });

    final newMessages = await _chatService.loadMoreMessages(
      widget.chatId,
      _firstMessage!,
    );

    setState(() {
      for (var message in newMessages) {
        if (!_allMessages.any((m) => m['id'] == message['id'])) {
          _allMessages.insert(0, message);
        }
      }

      _firstMessage = _allMessages.isNotEmpty ? _allMessages.first : null;

      if (newMessages.isEmpty) {
        _hasMoreMessages = false; // Không còn tin nhắn để tải
      }

      _isLoadingMore = false;
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final newMessage = await _chatService.sendMessage(
      widget.chatId,
      widget.myId,
      widget.friendId,
      _messageController.text,
    );

    setState(() {
      _allMessages.add(newMessage);
    });

    _messageController.clear();
    _scrollToBottom();
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
            Navigator.pop(context);
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
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _chatService.getMessagesStream(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Lỗi: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.data!.isEmpty) {
                      return const Center(child: Text("Chưa có tin nhắn nào"));
                    }

                    final newMessages = snapshot.data!;

                    if (_isFirstLoad) {
                      _allMessages = newMessages.reversed.toList();
                      _isFirstLoad = false;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToBottom();
                      });
                    } else {
                      for (var message in newMessages) {
                        if (message['sender_id'] != widget.myId) {
                          if (!_allMessages.any(
                            (m) => m['id'] == message['id'],
                          )) {
                            _allMessages.add(message);
                            if (_isAtBottom) {
                              _scrollToBottom();
                            } else {
                              setState(() {
                                _hasNewMessage = true;
                              });
                            }
                          }
                        } else {
                          final existingMessageIndex = _allMessages.indexWhere(
                            (m) => m['id'] == message['id'],
                          );
                          if (existingMessageIndex != -1) {
                            _allMessages[existingMessageIndex]['timestamp'] =
                                message['timestamp'];
                          }
                        }
                      }

                      _allMessages.sort((a, b) {
                        final aTimestamp = DateTime.parse(a['timestamp']);
                        final bTimestamp = DateTime.parse(b['timestamp']);
                        return aTimestamp.compareTo(bTimestamp);
                      });
                    }

                    _firstMessage =
                        _allMessages.isNotEmpty ? _allMessages.first : null;
                    _hasMoreMessages = true;

                    return MessageList(
                      messages: _allMessages,
                      myId: widget.myId,
                      friendImage: widget.friendImage,
                      scrollController: _scrollController,
                      isLoadingMore: _isLoadingMore,
                      hasMoreMessages: _hasMoreMessages,
                      selectedMessages: _selectedMessages,
                      onMessageTap: _onMessageTap,
                    );
                  },
                ),
              ),
              MessageInput(
                controller: _messageController,
                onSend: _sendMessage,
                onSendMedia: (mediaType) {
                  // Tạm thời bỏ qua gửi ảnh/video
                },
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
    super.dispose();
  }
}
