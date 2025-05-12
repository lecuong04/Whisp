import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/presentation/screens/messages_screen.dart';
import 'package:whisp/presentation/widgets/chat_title.dart';
import 'package:whisp/services/chat_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class Chats extends StatefulWidget {
  const Chats({super.key});

  @override
  State<StatefulWidget> createState() => _ChatsState();
}

class _ChatsState extends State<Chats> {
  String? myId;
  String? myFullName;
  final ChatService chatService = ChatService();
  List<Map<String, dynamic>> chats = [];
  bool isLoading = true;
  String? error;
  RealtimeChannel? chatChannel;

  @override
  void initState() {
    super.initState();
    initializeUser();
  }

  Future<void> initializeUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        error = "Người dùng chưa đăng nhập.";
        isLoading = false;
      });
      return;
    }
    try {
      final userId = user.id;
      Map<String, dynamic>? userInfo;

      try {
        userInfo = await chatService.getUserInfo(userId);
      } catch (e) {
        print('Error fetching user info: $e');
        throw Exception('Lỗi khi tải thông tin người dùng: $e');
      }

      final fullName = userInfo?['full_name'] as String? ?? 'User';

      setState(() {
        myId = userId;
        myFullName = fullName;
      });

      await loadChats();
    } catch (e) {
      setState(() {
        error = "Lỗi khi khởi tạo: $e";
        isLoading = false;
      });
    }
  }

  Future<void> loadChats() async {
    try {
      final tmpChats = await chatService.loadChatsByUserId(myId!);
      setState(() {
        chats = tmpChats;
        isLoading = false;
      });

      final isOnline =
          !(await Connectivity().checkConnectivity()).contains(
            ConnectivityResult.none,
          );
      if (!isOnline) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Không có kết nối mạng')));
        return;
      }

      // Hủy subscription cũ trước khi tạo mới
      if (chatChannel != null) {
        await Supabase.instance.client.removeChannel(chatChannel!);
        chatChannel = null;
      }

      chatChannel = Supabase.instance.client.channel('public:chats:$myId');
      chatService.subscribeToChats(myId!, (updatedChats) {
        if (mounted && updatedChats.isNotEmpty) {
          setState(() {
            chats = updatedChats;
          });
        }
      });
    } catch (e) {
      print('Error loading chats: $e');
      setState(() {
        error = "Lỗi khi tải danh sách chat: $e";
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không có kết nối mạng')));
    }
  }

  void updateChatReadStatus(String conversationId) {
    setState(() {
      chats =
          chats.map((chat) {
            if (chat['conversation_id'] == conversationId) {
              return {...chat, 'is_read': true};
            }
            return chat;
          }).toList();
      print('Updated local is_read for $conversationId: $chats');
    });

    chatService.updateChatReadStatus(myId!, conversationId).catchError((e) {
      print('Error updating chat read status: $e');
    });
  }

  Future<void> deleteChat(String conversationId) async {
    try {
      await chatService.markChatAsDeleted(myId!, conversationId);
      setState(() {
        chats.removeWhere((chat) => chat['conversation_id'] == conversationId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa cuộc trò chuyện')));
    } catch (e) {
      print('Error deleting conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa cuộc trò chuyện: $e')),
      );
    }
  }

  @override
  void dispose() {
    if (chatChannel != null) {
      Supabase.instance.client.removeChannel(chatChannel!);
      chatChannel = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text("Đang tải..."),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Text(
          "Lỗi: $error",
          style: const TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (myId == null) {
      return const Center(
        child: Text(
          "Lỗi: Người dùng chưa đăng nhập.",
          style: TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const Divider(height: 8),
        Expanded(
          child:
              chats.isEmpty
                  ? Stack(
                    children: [
                      RefreshIndicator(
                        onRefresh: () async {
                          await loadChats();
                        },
                        child: ListView(),
                      ),
                      const Center(
                        child: Text(
                          "Không có đoạn chat nào.\nHãy bắt đầu một cuộc trò chuyện mới!",
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                  : RefreshIndicator(
                    child: ListView.builder(
                      scrollDirection: Axis.vertical,
                      padding: const EdgeInsets.only(bottom: 10),
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        final conversationId =
                            chat['conversation_id'] as String;
                        final friendId = chat['friend_id'] as String?;
                        final alias =
                            chat['friend_full_name'] as String? ?? 'Unknown';
                        final avatarUrl =
                            chat['friend_avatar_url'] as String? ?? '';
                        final lastMessage =
                            chat['last_message'] as String? ??
                            'Chưa có tin nhắn';
                        final lastMessageTime =
                            chat['last_message_time'] as DateTime?;
                        final isOnline = chat['friend_status'] == 'online';
                        final isSeen = chat['is_read'] as bool? ?? true;

                        // Bỏ qua chat nếu friendId hoặc lastMessageTime là null
                        if (friendId == null || lastMessageTime == null) {
                          print(
                            'Skipping chat with null friend_id or last_message_time: $conversationId',
                          );
                          return const SizedBox.shrink();
                        }

                        print(
                          'Chat: $conversationId, FriendId: $friendId, Alias: $alias, LastMessage: $lastMessage, LastMessageTime: $lastMessageTime, IsOnline: $isOnline, IsSeen: $isSeen',
                        );
                        return Column(
                          children: [
                            Slidable(
                              key: ValueKey(conversationId),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.4,
                                children: [
                                  SlidableAction(
                                    onPressed: (_) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Xem thêm'),
                                        ),
                                      );
                                    },
                                    backgroundColor: Colors.black45,
                                    foregroundColor: Colors.white,
                                    icon: FontAwesomeIcons.ellipsis,
                                  ),
                                  SlidableAction(
                                    onPressed: (_) async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (context) => AlertDialog(
                                              title: const Text('Xác nhận xóa'),
                                              content: const Text(
                                                'Bạn có chắc muốn xóa cuộc trò chuyện này?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Hủy'),
                                                ),
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text('Xóa'),
                                                ),
                                              ],
                                            ),
                                      );
                                      if (confirm == true) {
                                        deleteChat(conversationId);
                                      }
                                    },
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: ChatTitle(
                                  avatarUrl,
                                  alias,
                                  lastMessageTime,
                                  isSeen,
                                  isOnline,
                                  lastMessage,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => MessagesScreen(
                                              conversationId: conversationId,
                                              conversationName: alias,
                                              conversationAvatar: avatarUrl,
                                            ),
                                      ),
                                    ).then((result) {
                                      if (result != null &&
                                          result['conversation_id'] != null) {
                                        updateChatReadStatus(
                                          result['conversation_id'],
                                        );
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: double.infinity,
                              child: Divider(height: 8, thickness: 1),
                            ),
                          ],
                        );
                      },
                    ),
                    onRefresh: () async {
                      await loadChats();
                    },
                  ),
        ),
      ],
    );
  }
}
