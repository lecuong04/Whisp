import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/presentation/screens/messages_screen.dart';
import 'package:whisp/presentation/widgets/chat_title.dart';
import 'package:whisp/services/chat_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:whisp/utils/helpers.dart';

class Chats extends StatefulWidget {
  const Chats({super.key});

  @override
  State<StatefulWidget> createState() => _ChatsState();
}

class _ChatsState extends State<Chats> {
  static Map<int, String> muteDuration = {
    1: "Trong 1 giờ",
    4: "Trong 4 giờ",
    12: "Trong 12 giờ",
    -1: "Cho đến khi mở lại",
  };

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

      final isOnline = !(await Connectivity().checkConnectivity()).contains(
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
      chats = chats.map((chat) {
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

  Future<bool> muteBottomModal(String conversationId) async {
    return await showModalBottomSheet(
          context: context,
          useSafeArea: true,
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.only(
                top: 20,
                left: 20,
                bottom: 10,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tắt thông báo tin nhắn mới',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  ...muteDuration.entries.map(
                    (option) => Column(
                      children: [
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.only(
                            left: 0.0,
                            right: 0.0,
                          ),
                          title: Text(
                            option.value,
                            style: TextStyle(fontSize: 16),
                          ),
                          onTap: () async {
                            var result = await ChatService()
                                .setMuteConversation(
                                  conversationId,
                                  option.key.toDouble(),
                                );
                            if (result != null) {
                              runAtSpecificTime(
                                result.add(Duration(seconds: 30)),
                                () async {
                                  await loadChats();
                                  if (mounted) {
                                    setState(() {});
                                  }
                                },
                              );
                            }
                            Navigator.pop(context, true);
                          },
                        ),
                        Divider(thickness: 1, height: 3, color: Colors.grey),
                      ],
                    ),
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.only(left: 0.0, right: 0.0),
                    title: Text("Tùy chỉnh", style: TextStyle(fontSize: 16)),
                    onTap: () async {
                      final now = DateTime.now();
                      var date = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: now,
                        lastDate: DateTime(now.year + 1),
                      );
                      if (date != null) {
                        var time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          var dateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                          var result = await ChatService().setMuteConversation(
                            conversationId,
                            dateTime.difference(DateTime.now()).inMinutes /
                                60.0,
                          );
                          if (result != null) {
                            runAtSpecificTime(
                              result.add(Duration(seconds: 30)),
                              () async {
                                await loadChats();
                                if (mounted) {
                                  setState(() {});
                                }
                              },
                            );
                          }
                          Navigator.pop(context, true);
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ) ??
        false;
  }

  Future<void> actionDialog({
    required String avatarUrl,
    required String alias,
    required String conversationId,
  }) async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SimpleDialog(
              contentPadding: EdgeInsets.all(10),
              title: Row(
                spacing: 10,
                children: [
                  CircleAvatar(
                    backgroundImage: avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                  ),
                  Text(alias),
                ],
              ),
              children: [
                FutureBuilder(
                  future: ChatService().isConversationMute(conversationId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const ElevatedButton(
                        onPressed: null,
                        child: Stack(
                          alignment: AlignmentDirectional.center,
                          children: [
                            Text("Tắt thông báo"),
                            CircularProgressIndicator(
                              padding: EdgeInsets.all(6),
                            ),
                          ],
                        ),
                      );
                    }
                    return ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(this.context);
                        bool isChanged = false;
                        if (!snapshot.data!) {
                          isChanged = await muteBottomModal(conversationId);
                        } else {
                          await ChatService().setMuteConversation(
                            conversationId,
                            0,
                          );
                          isChanged = true;
                        }
                        if (isChanged) {
                          await loadChats();
                          this.setState(() {});
                        }
                      },
                      child: Text(
                        !snapshot.data! ? "Tắt thông báo" : "Bật thông báo",
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
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
          child: chats.isEmpty
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
                      final conversationId = chat['conversation_id'] as String;
                      final friendId = chat['friend_id'] as String?;
                      final alias =
                          chat['friend_full_name'] as String? ?? 'Unknown';
                      final avatarUrl =
                          chat['friend_avatar_url'] as String? ?? '';
                      final lastMessage =
                          chat['last_message'] as String? ?? 'Chưa có tin nhắn';
                      final lastMessageTime =
                          chat['last_message_time'] as DateTime?;
                      final isOnline = chat['friend_status'] == 'online';
                      final isSeen = chat['is_read'] as bool? ?? true;
                      final isMute = chat['is_mute'] as bool? ?? false;

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
                                  onPressed: (context) async {
                                    await actionDialog(
                                      avatarUrl: avatarUrl,
                                      alias: alias,
                                      conversationId: conversationId,
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
                                      builder: (context) => AlertDialog(
                                        title: const Text('Xác nhận xóa'),
                                        content: const Text(
                                          'Bạn có chắc muốn xóa cuộc trò chuyện này?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Hủy'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
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
                                isMute,
                                lastMessage,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MessagesScreen(
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
