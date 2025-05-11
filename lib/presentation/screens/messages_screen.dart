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
  bool isLoadingNewer = false;
  bool hasNewerMessages = true;
  bool isSearchMode = false;
  String? error;
  final Set<int> selectedMessages = {};
  double _lastScrollPosition = 0.0;
  bool _isScrollingUp = false;

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

    // Xác định hướng cuộn
    setState(() {
      _isScrollingUp = currentScroll < _lastScrollPosition;
      _lastScrollPosition = currentScroll;

      isAtBottom = (maxScroll - currentScroll) <= threshold;
      if (isAtBottom) {
        hasNewMessage = false;
      }
    });

    // Tải tin nhắn cũ hơn khi cuộn lên gần đầu danh sách và đang cuộn lên
    if (currentScroll <= threshold &&
        hasMoreMessages &&
        !isLoadingMore &&
        _isScrollingUp) {
      loadMoreMessages();
    }

    // Tải tin nhắn mới hơn khi cuộn xuống gần cuối danh sách
    if (currentScroll >= maxScroll - threshold &&
        hasNewerMessages &&
        !isLoadingNewer) {
      loadNewerMessages();
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

      List<Map<String, dynamic>> messages;
      if (widget.messageId != null) {
        messages = await chatService.loadMessagesAroundMessageId(
          widget.conversationId,
          widget.messageId!,
          limit: MESSAGE_PAGE_SIZE,
        );
        isSearchMode = true; // Đặt chế độ tìm kiếm
      } else {
        messages = await chatService.loadMessages(
          widget.conversationId,
          limit: MESSAGE_PAGE_SIZE,
        );
        isSearchMode = false; // Chế độ bình thường
      }

      setState(() {
        allMessages = messages.reversed.toList();
        isLoading = false;
        hasMoreMessages = messages.length == MESSAGE_PAGE_SIZE;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.messageId != null) {
          final targetIndex = allMessages.indexWhere(
            (msg) => msg['id'] == widget.messageId,
          );
          if (targetIndex != -1 && scrollController.hasClients) {
            scrollController.animateTo(
              targetIndex * 100.0, // Điều chỉnh theo chiều cao tin nhắn thực tế
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else {
            scrollToBottom();
          }
        } else {
          scrollToBottom();
        }
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

  Future<void> loadNewerMessages() async {
    if (!hasNewerMessages || isLoadingNewer) return;

    setState(() {
      isLoadingNewer = true;
    });

    try {
      final newestMessage = allMessages.last;
      final afterSentAt = newestMessage['sent_at'];

      final newerMessages = await chatService.loadNewerMessages(
        widget.conversationId,
        afterSentAt: afterSentAt,
        limit: MESSAGE_PAGE_SIZE,
      );

      if (newerMessages.isNotEmpty) {
        setState(() {
          final newMessages =
              newerMessages.where((newMsg) {
                return !allMessages.any(
                  (oldMsg) => oldMsg['id'] == newMsg['id'],
                );
              }).toList();
          allMessages.addAll(newMessages);
          allMessages.sort((a, b) {
            final aTime = DateTime.parse(a['sent_at']);
            final bTime = DateTime.parse(b['sent_at']);
            return aTime.compareTo(bTime);
          });
          isLoadingNewer = false;
          hasNewerMessages = newerMessages.length == MESSAGE_PAGE_SIZE;

          // Đánh dấu tin nhắn mới từ người khác là đã đọc
          if (newMessages.any((msg) => msg['sender_id'] != myId)) {
            chatService.markMessagesAsRead(widget.conversationId).catchError((
              e,
            ) {
              print('Cảnh báo: Không thể đánh dấu tin nhắn đã đọc: $e');
            });
          }

          // Nếu không còn tin nhắn mới hơn, thoát chế độ tìm kiếm
          if (!hasNewerMessages) {
            isSearchMode = false;
          }
        });
      } else {
        setState(() {
          isLoadingNewer = false;
          hasNewerMessages = false;
          isSearchMode =
              false; // Thoát chế độ tìm kiếm nếu không còn tin nhắn mới
        });
      }
    } catch (e) {
      error = "Lỗi khi tải tin nhắn mới hơn: $e";
      isLoadingNewer = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi tải tin nhắn mới hơn')));
      setState(() {});
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
                        : RefreshIndicator(
                          onRefresh: loadNewerMessages,
                          child: MessageList(
                            messages: allMessages,
                            myId: myId,
                            friendImage: widget.conversationAvatar,
                            scrollController: scrollController,
                            isLoadingMore: isLoadingMore,
                            hasMoreMessages: hasMoreMessages,
                            selectedMessages: selectedMessages,
                            onMessageTap: onMessageTap,
                            targetMessageId:
                                widget.messageId, // Truyền messageId
                          ),
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
