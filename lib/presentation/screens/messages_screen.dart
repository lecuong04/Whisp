import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:whisp/custom_cache_manager.dart';
import 'package:whisp/services/chat_service.dart';
import 'package:whisp/presentation/widgets/message_list.dart';
import 'package:whisp/presentation/widgets/message_input.dart';
import 'package:whisp/services/user_service.dart';
import 'package:whisp/utils/constants.dart'; // Import constants.dart
import 'dart:io';

class MessagesScreen extends StatefulWidget {
  final String conversationId;
  final String conversationName;
  final String conversationAvatar;
  final String? messageId;

  const MessagesScreen({
    super.key,
    required this.conversationId,
    required this.conversationName,
    required this.conversationAvatar,
    this.messageId,
  });

  @override
  State createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String myId = UserService().id!;

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final ChatService chatService = ChatService();
  List<Map<String, dynamic>> allMessages = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool isAtBottom = true;
  bool hasNewMessage = false;
  bool hasMoreMessages = true;
  String? error;
  final Set<int> selectedMessages = {};

  @override
  void initState() {
    super.initState();
    scrollController.addListener(scrollListener);
    initializeMessages();
  }

  void scrollListener() {
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    const threshold = 100.0;

    setState(() {
      isAtBottom = (maxScroll - currentScroll) <= threshold;
      if (isAtBottom) {
        hasNewMessage = false;
      }
    });

    if (currentScroll <= 100 && hasMoreMessages && !isLoadingMore) {
      loadMoreMessages();
    }
  }

  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        isAtBottom = true;
        hasNewMessage = false;
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToBottom();
      });
    }
  }

  Future<void> initializeMessages() async {
    try {
      chatService.markMessagesAsRead(widget.conversationId).catchError((e) {
        print('Cảnh báo: Không thể đánh dấu tin nhắn đã đọc: $e');
      });

      final messages = await chatService.loadMessages(
        widget.conversationId,
        limit: MESSAGE_PAGE_SIZE,
      );
      setState(() {
        allMessages = messages.reversed.toList();
        isLoading = false;
        hasMoreMessages = messages.length == MESSAGE_PAGE_SIZE;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToBottom();
      });

      chatService.subscribeToMessages(widget.conversationId, (updatedMessages) {
        final newMessages =
            updatedMessages.where((newMsg) {
              return !allMessages.any((oldMsg) => oldMsg['id'] == newMsg['id']);
            }).toList();

        if (newMessages.isNotEmpty) {
          allMessages.addAll(newMessages);
          allMessages.sort((a, b) {
            final aTime = DateTime.parse(a['sent_at']);
            final bTime = DateTime.parse(b['sent_at']);
            return aTime.compareTo(bTime);
          });

          if (newMessages.any((msg) => msg['sender_id'] != myId)) {
            chatService.markMessagesAsRead(widget.conversationId).catchError((
              e,
            ) {
              print('Cảnh báo: Không thể đánh dấu tin nhắn đã đọc: $e');
            });
          }

          if (isAtBottom) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              scrollToBottom();
            });
          } else {
            hasNewMessage = true;
          }
        }
        setState(() {});
      });
    } catch (e) {
      error = "Lỗi khi tải tin nhắn: $e";
      isLoading = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> loadMoreMessages() async {
    if (!hasMoreMessages || isLoadingMore) return;

    setState(() {
      isLoadingMore = true;
    });

    try {
      final oldestMessage = allMessages.first;
      final beforeSentAt = oldestMessage['sent_at'];
      final olderMessages = await chatService.loadMessages(
        widget.conversationId,
        limit: MESSAGE_PAGE_SIZE,
        beforeSentAt: beforeSentAt,
      );

      if (olderMessages.isNotEmpty) {
        setState(() {
          final newMessages =
              olderMessages.where((newMsg) {
                return !allMessages.any(
                  (oldMsg) => oldMsg['id'] == newMsg['id'],
                );
              }).toList();
          allMessages.insertAll(0, newMessages.reversed);
          isLoadingMore = false;
          hasMoreMessages = olderMessages.length == MESSAGE_PAGE_SIZE;
        });
      } else {
        setState(() {
          isLoadingMore = false;
          hasMoreMessages = false;
        });
      }
    } catch (e) {
      error = "Lỗi khi tải thêm tin nhắn: $e";
      isLoadingMore = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi tải thêm tin nhắn')));
      setState(() {});
    }
  }

  void sendMessage() async {
    if (messageController.text.trim().isEmpty) return;

    try {
      final newMessage = await chatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: myId,
        content: messageController.text,
      );

      setState(() {
        allMessages.add(newMessage);
        allMessages.sort((a, b) {
          final aTime = DateTime.parse(a['sent_at']);
          final bTime = DateTime.parse(b['sent_at']);
          return aTime.compareTo(bTime);
        });
      });

      messageController.clear();
      scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi gửi tin nhắn: $e')));
    }
  }

  void sendMedia(File file, String messageType) async {
    try {
      final newMessage = await chatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: myId,
        content: '',
        messageType: messageType,
        mediaFile: file,
      );

      setState(() {
        allMessages.add(newMessage);
        allMessages.sort((a, b) {
          final aTime = DateTime.parse(a['sent_at']);
          final bTime = DateTime.parse(b['sent_at']);
          return aTime.compareTo(bTime);
        });
      });

      scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi gửi media: $e')));
    }
  }

  void onMessageTap(int index) {
    setState(() {
      if (selectedMessages.contains(index)) {
        selectedMessages.remove(index);
      } else {
        selectedMessages.add(index);
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
                  widget.conversationAvatar.isNotEmpty
                      ? CachedNetworkImageProvider(
                        widget.conversationAvatar,
                        cacheManager: CustomCacheManager(),
                      )
                      : null,
              radius: 20,
            ),
            const SizedBox(width: 10),
            Text(widget.conversationName),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context, {'conversation_id': widget.conversationId});
          },
          icon: const Icon(FontAwesomeIcons.chevronLeft),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child:
                    isLoading && allMessages.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : error != null
                        ? Center(
                          child: Text(
                            "Lỗi: $error",
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                        : allMessages.isEmpty
                        ? const Center(child: Text("Chưa có tin nhắn nào"))
                        : MessageList(
                          messages: allMessages,
                          myId: myId,
                          friendImage: widget.conversationAvatar,
                          scrollController: scrollController,
                          isLoadingMore: isLoadingMore,
                          hasMoreMessages: hasMoreMessages,
                          selectedMessages: selectedMessages,
                          onMessageTap: onMessageTap,
                        ),
              ),
              MessageInput(
                controller: messageController,
                onSend: sendMessage,
                onTextFieldTap: () {},
                onMediaSelected: sendMedia,
              ),
            ],
          ),
          if (hasNewMessage)
            Positioned(
              bottom: 80,
              right: 20,
              child: FloatingActionButton(
                onPressed: scrollToBottom,
                child: const Icon(Icons.arrow_downward),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    scrollController.dispose();
    messageController.dispose();
    chatService.unsubscribeMessages();
    super.dispose();
  }
}
