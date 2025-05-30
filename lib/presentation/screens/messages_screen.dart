import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:whisp/custom_cache_manager.dart';
import 'package:whisp/presentation/widgets/message_audio.dart';
import 'package:whisp/presentation/widgets/message_list.dart';
import 'package:whisp/presentation/widgets/message_input.dart';
import 'package:whisp/presentation/widgets/message_media_tab.dart';
import 'package:whisp/services/chat_service.dart';
import 'package:whisp/services/user_service.dart';
import 'package:whisp/utils/constants.dart';
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
  bool isSending = false;
  final Set<int> selectedMessages = {};
  double lastScrollPosition = 0.0;
  bool isScrollingUp = false;
  DateTime lastLoadMoreTime = DateTime.now();
  DateTime lastLoadNewerTime = DateTime.now();
  bool justInitializedSearch = false;

  String? error;
  double? inputHeight;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(scrollListener);
    initializeMessages();
  }

  @override
  void dispose() {
    scrollController.dispose();
    messageController.dispose();
    chatService.unsubscribeMessages();
    super.dispose();
  }

  void scrollListener() {
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    const endThreshold =
        10.0; // Ngưỡng nhỏ để xác định khi ở gần cuối danh sách
    const minLoadInterval = Duration(seconds: 1);

    isScrollingUp = currentScroll > lastScrollPosition;
    lastScrollPosition = currentScroll;

    // Kiểm tra xem có ở gần cuối danh sách hay không
    final isNearEnd = currentScroll >= maxScroll - endThreshold;

    // Cập nhật trạng thái isAtBottom
    final newIsAtBottom = currentScroll <= 200.0; // Giữ ngưỡng cho isAtBottom
    if (newIsAtBottom != isAtBottom) {
      if (!mounted) return;
      setState(() {
        isAtBottom = newIsAtBottom;
        if (isAtBottom) {
          hasNewMessage = false;
        }
      });
    }

    // Chỉ gọi loadMoreMessages khi:
    // - Đã cuộn đến gần cuối danh sách (isNearEnd)
    // - Có tin nhắn cũ hơn để tải (hasMoreMessages)
    // - Không đang tải (isLoadingMore = false)
    // - Đang kéo lên (isScrollingUp)
    // - Không vừa khởi tạo tìm kiếm (_justInitializedSearch = false)
    // - Đã qua khoảng thời gian tối thiểu (minLoadInterval)
    if (isNearEnd &&
        hasMoreMessages &&
        !isLoadingMore &&
        isScrollingUp &&
        !justInitializedSearch &&
        DateTime.now().difference(lastLoadMoreTime) >= minLoadInterval) {
      loadMoreMessages();
      lastLoadMoreTime = DateTime.now();
    }

    // Tải tin nhắn mới hơn khi cuộn xuống gần đầu danh sách
    if (currentScroll <= 200.0 &&
        hasNewerMessages &&
        !isLoadingNewer &&
        DateTime.now().difference(lastLoadNewerTime) >= minLoadInterval) {
      loadNewerMessages();
      lastLoadNewerTime = DateTime.now();
    }
  }

  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
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

      dynamic result;
      if (widget.messageId != null) {
        result = await chatService.loadMessagesAroundMessageId(
          widget.conversationId,
          widget.messageId!,
          limit: 20,
        );
        isSearchMode = true;
        justInitializedSearch = true;
      } else {
        result = await chatService.loadMessages(
          widget.conversationId,
          limit: MESSAGE_PAGE_SIZE,
        );
        isSearchMode = false;
        justInitializedSearch = false;
      }

      List<Map<String, dynamic>> messages;
      int? targetIndex;

      if (widget.messageId != null) {
        messages = result['messages'] as List<Map<String, dynamic>>;
        targetIndex = result['targetIndex'] as int;
      } else {
        messages = result as List<Map<String, dynamic>>;
      }

      if (!mounted) return;
      setState(() {
        allMessages = messages.toList();
        isLoading = false;
        hasMoreMessages =
            messages.length == 20 || messages.length == MESSAGE_PAGE_SIZE;
        hasNewerMessages =
            messages.length == 20 || messages.length == MESSAGE_PAGE_SIZE;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.messageId != null && targetIndex != null) {
          if (scrollController.hasClients) {
            final estimatedPosition = targetIndex * 100.0;
            scrollController.animateTo(
              estimatedPosition,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else {
            scrollToBottom();
          }
        } else {
          scrollToBottom();
        }
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          setState(() {
            justInitializedSearch = false;
          });
        });
      });

      chatService.subscribeToMessages(widget.conversationId, (updatedMessages) {
        if (!mounted) return;
        setState(() {
          for (var updatedMessage in updatedMessages) {
            final index = allMessages.indexWhere(
              (msg) => msg['id'] == updatedMessage['id'],
            );
            if (index != -1) {
              allMessages[index] = updatedMessage;
            } else {
              allMessages.insert(0, updatedMessage);
            }
          }
          allMessages.sort((a, b) {
            final aTime = DateTime.parse(a['sent_at']);
            final bTime = DateTime.parse(b['sent_at']);
            return bTime.compareTo(aTime);
          });
        });

        if (updatedMessages.any((msg) => msg['sender_id'] != myId)) {
          chatService.markMessagesAsRead(widget.conversationId).catchError((e) {
            print('Cảnh báo: Không thể đánh dấu tin nhắn đã đọc: $e');
          });
        }

        if (isAtBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            scrollToBottom();
          });
        } else {
          if (!mounted) return;
          setState(() {
            hasNewMessage = true;
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = "Lỗi khi tải tin nhắn: $e";
        isLoading = false;
      });
    }
  }

  Future<void> loadMoreMessages() async {
    if (!hasMoreMessages || isLoadingMore) return;

    if (!mounted) return;
    setState(() {
      isLoadingMore = true;
    });

    try {
      final oldestMessage = allMessages.last;
      final beforeSentAt = oldestMessage['sent_at'];
      final olderMessages = await chatService.loadMessages(
        widget.conversationId,
        limit: MESSAGE_PAGE_SIZE,
        beforeSentAt: beforeSentAt,
      );

      if (!mounted) return;
      setState(() {
        if (olderMessages.isNotEmpty) {
          final newMessages = olderMessages.where((newMsg) {
            return !allMessages.any((oldMsg) => oldMsg['id'] == newMsg['id']);
          }).toList();
          allMessages.addAll(newMessages);
          hasMoreMessages = olderMessages.length == MESSAGE_PAGE_SIZE;
        } else {
          hasMoreMessages = false;
        }
        isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = "Lỗi khi tải thêm tin nhắn: $e";
        isLoadingMore = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi tải thêm tin nhắn')));
    }
  }

  Future<void> loadNewerMessages() async {
    if (!hasNewerMessages || isLoadingNewer) return;

    if (!mounted) return;
    setState(() {
      isLoadingNewer = true;
    });

    try {
      final newestMessage = allMessages.first;
      final afterSentAt = newestMessage['sent_at'];

      final newerMessages = await chatService.loadNewerMessages(
        widget.conversationId,
        afterSentAt: afterSentAt,
        limit: MESSAGE_PAGE_SIZE,
      );

      if (!mounted) return;
      setState(() {
        if (newerMessages.isNotEmpty) {
          final newMessages = newerMessages.where((newMsg) {
            return !allMessages.any((oldMsg) => oldMsg['id'] == newMsg['id']);
          }).toList();
          allMessages.insertAll(0, newMessages);
          allMessages.sort((a, b) {
            final aTime = DateTime.parse(a['sent_at']);
            final bTime = DateTime.parse(b['sent_at']);
            return bTime.compareTo(aTime);
          });
          hasNewerMessages = newerMessages.length == MESSAGE_PAGE_SIZE;

          if (newMessages.any((msg) => msg['sender_id'] != myId)) {
            chatService.markMessagesAsRead(widget.conversationId).catchError((
              e,
            ) {
              print('Cảnh báo: Không thể đánh dấu tin nhắn đã đọc: $e');
            });
          }

          if (!hasNewerMessages) {
            isSearchMode = false;
          }
        } else {
          hasNewerMessages = false;
          isSearchMode = false;
        }
        isLoadingNewer = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = "Lỗi khi tải tin nhắn mới hơn: $e";
        isLoadingNewer = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi tải tin nhắn mới hơn')));
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

      if (!mounted) return;
      setState(() {
        allMessages.insert(0, newMessage);
        allMessages.sort((a, b) {
          final aTime = DateTime.parse(a['sent_at']);
          final bTime = DateTime.parse(b['sent_at']);
          return bTime.compareTo(aTime);
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
      final newMessage = chatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: myId,
        content: '',
        messageType: messageType,
        mediaFile: file,
      );
      setState(() {
        isSending = true;
      });
      allMessages.insert(0, await newMessage);
      setState(() {
        isSending = false;
      });
      if (!mounted) return;
      setState(() {
        allMessages.sort((a, b) {
          final aTime = DateTime.parse(a['sent_at']);
          final bTime = DateTime.parse(b['sent_at']);
          return bTime.compareTo(aTime);
        });
      });

      scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi gửi media: $e')));
    }
  }

  void onMessageHold(int index) async {
    final message = allMessages[index];
    final isMe = message['sender_id'] == myId;

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Xóa đối với bạn'),
              onTap: () => Navigator.pop(context, 'delete_for_me'),
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('Xóa đối với mọi người'),
                onTap: () => Navigator.pop(context, 'delete_for_all'),
              ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        if (result == 'delete_for_me') {
          await chatService.deleteMessageForMe(message['id'], myId);
          if (!mounted) return;
          setState(() {
            allMessages[index]['message_statuses'] = [
              ...(message['message_statuses'] as List<dynamic>).map(
                (status) => status['user_id'] == myId
                    ? {...status, 'is_hidden': true}
                    : status,
              ),
            ];
          });
        } else if (result == 'delete_for_all') {
          await chatService.deleteMessageForAll(message['id']);
          if (!mounted) return;
          setState(() {
            allMessages[index]['message_statuses'] = [
              ...(message['message_statuses'] as List<dynamic>).map(
                (status) => {...status, 'is_hidden': true},
              ),
            ];
          });
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tin nhắn đã được xóa')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa tin nhắn: $e')));
      }
    } else {
      if (!mounted) return;
      setState(() {
        if (selectedMessages.contains(index)) {
          selectedMessages.remove(index);
        } else {
          selectedMessages.add(index);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.conversationAvatar.isNotEmpty
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
        actions: [
          Builder(
            builder: (context) => IconButton(
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
              icon: const Icon(Icons.storage_outlined, color: Colors.black),
            ),
          ),
        ],
      ),
      endDrawer: MessageMediaTab(conversationId: widget.conversationId),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: isLoading && allMessages.isEmpty
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
                        onMessageHold: onMessageHold,
                        targetMessageId: widget.messageId,
                      ),
              ),
              ...(isSending ? [LinearProgressIndicator()] : []),
              Divider(height: 1),
              inputHeight == null
                  ? MessageInput(
                      controller: messageController,
                      onSend: sendMessage,
                      onMediaSelected: sendMedia,
                      onAudioRecorderClick: (height) {
                        inputHeight = height;
                        setState(() {});
                      },
                      contentInsertionConfiguration:
                          ContentInsertionConfiguration(
                            onContentInserted: (value) {},
                          ),
                    )
                  : MessageAudio(
                      inputHeight: inputHeight!,
                      onMediaSelected: sendMedia,
                      onDeleteAudio: () {
                        inputHeight = null;
                        setState(() {});
                      },
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
}
