import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:whisp/custom_cache_manager.dart';
import 'package:whisp/presentation/widgets/message_list.dart';
import 'package:whisp/presentation/widgets/message_input.dart';
import 'package:whisp/presentation/widgets/message_media_list.dart';
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

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
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
  double keyboardHeight = 0;
  final Set<int> selectedMessages = {};
  double lastScrollPosition = 0.0;
  bool isScrollingUp = false;
  DateTime lastLoadMoreTime = DateTime.now();
  DateTime lastLoadNewerTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scrollController.addListener(scrollListener);
    initializeMessages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scrollController.dispose();
    messageController.dispose();
    chatService.unsubscribeMessages();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (keyboardHeight != 0) {
      scrollController.animateTo(
        scrollController.position.pixels - keyboardHeight,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      keyboardHeight = 0;
    }
  }

  void scrollListener() {
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    final threshold = isSearchMode ? 50.0 : 200.0;
    const minLoadInterval = Duration(seconds: 1);

    isScrollingUp = currentScroll < lastScrollPosition;
    lastScrollPosition = currentScroll;

    final newIsAtBottom = (maxScroll - currentScroll) <= threshold;
    if (newIsAtBottom != isAtBottom) {
      if (!mounted) return;
      setState(() {
        isAtBottom = newIsAtBottom;
        if (isAtBottom) {
          hasNewMessage = false;
        }
      });
    }

    if (currentScroll <= threshold &&
        hasMoreMessages &&
        !isLoadingMore &&
        isScrollingUp &&
        DateTime.now().difference(lastLoadMoreTime) >= minLoadInterval) {
      loadMoreMessages();
      lastLoadMoreTime = DateTime.now();
    }

    if (currentScroll >= maxScroll - threshold &&
        hasNewerMessages &&
        !isLoadingNewer &&
        DateTime.now().difference(lastLoadNewerTime) >= minLoadInterval) {
      loadNewerMessages();
      lastLoadNewerTime = DateTime.now();
    }
  }

  void scrollToBottom() async {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
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
          limit: MESSAGE_PAGE_SIZE,
        );
        isSearchMode = true;
      } else {
        result = await chatService.loadMessages(
          widget.conversationId,
          limit: MESSAGE_PAGE_SIZE,
        );
        isSearchMode = false;
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
        allMessages = messages.reversed.toList();
        isLoading = false;
        hasMoreMessages = messages.length == MESSAGE_PAGE_SIZE;
        hasNewerMessages = messages.length == MESSAGE_PAGE_SIZE;
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

            if (targetIndex < 5) {
              Future.delayed(const Duration(milliseconds: 400), () {
                if (!mounted || !scrollController.hasClients) return;
                scrollController.jumpTo(50.0);
              });
            }
          } else {
            scrollToBottom();
          }
        } else {
          scrollToBottom();
        }
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
              allMessages.add(updatedMessage);
            }
          }
          allMessages.sort((a, b) {
            final aTime = DateTime.parse(a['sent_at']);
            final bTime = DateTime.parse(b['sent_at']);
            return aTime.compareTo(bTime);
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
      final oldestMessage = allMessages.first;
      final beforeSentAt = oldestMessage['sent_at'];
      final olderMessages = await chatService.loadMessages(
        widget.conversationId,
        limit: MESSAGE_PAGE_SIZE,
        beforeSentAt: beforeSentAt,
      );

      if (!mounted) return;
      setState(() {
        if (olderMessages.isNotEmpty) {
          final newMessages =
              olderMessages.where((newMsg) {
                return !allMessages.any(
                  (oldMsg) => oldMsg['id'] == newMsg['id'],
                );
              }).toList();
          allMessages.insertAll(0, newMessages.reversed);
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
      final newestMessage = allMessages.last;
      final afterSentAt = newestMessage['sent_at'];

      final newerMessages = await chatService.loadNewerMessages(
        widget.conversationId,
        afterSentAt: afterSentAt,
        limit: MESSAGE_PAGE_SIZE,
      );

      if (!mounted) return;
      setState(() {
        if (newerMessages.isNotEmpty) {
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
      final newMessage = chatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: myId,
        content: '',
        messageType: messageType,
        mediaFile: file,
      );

      allMessages.add(await newMessage);
      if (!mounted) return;
      setState(() {
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

  void onMessageHold(int index) async {
    final message = allMessages[index];
    final isMe = message['sender_id'] == myId;

    final result = await showModalBottomSheet<String>(
      context: context,
      builder:
          (context) => Container(
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
                (status) =>
                    status['user_id'] == myId
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
        actions: [
          Builder(
            builder:
                (context) => IconButton(
                  onPressed: () {
                    Scaffold.of(context).openEndDrawer();
                  },
                  icon: const Icon(Icons.storage_outlined, color: Colors.black),
                ),
          ),
        ],
      ),
      endDrawer: MessageMediaList(conversationId: widget.conversationId),
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
                          onMessageHold: onMessageHold,
                          targetMessageId: widget.messageId,
                        ),
              ),
              MessageInput(
                controller: messageController,
                onSend: sendMessage,
                onTextFieldTap: () {
                  Future.delayed(Duration(milliseconds: 300), () {
                    if (keyboardHeight == 0) {
                      keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
                    }
                    print("Keyboard height 2: $keyboardHeight");
                    scrollController.animateTo(
                      scrollController.position.pixels +
                          MediaQuery.of(context).viewInsets.bottom,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  });
                },
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
}
