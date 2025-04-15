import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/presentation/screens/messages.dart';
import 'package:whisp/presentation/widgets/chat_title.dart';
import 'package:whisp/presentation/widgets/search.dart';
import 'package:whisp/services/chat_service.dart';

class Chats extends StatefulWidget {
  const Chats({super.key});

  @override
  State<StatefulWidget> createState() => ChatsState();
}

class ChatsState extends State<Chats> {
  String? myId;
  String? myUsername;
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = "Người dùng chưa đăng nhập.";
          _isLoading = false;
        });
        return;
      }

      final userId = user.id;
      final userInfo = await _chatService.getUserInfo(userId);
      final username = userInfo?['username'] as String? ?? 'User';

      setState(() {
        myId = userId;
        myUsername = username;
      });

      await _loadChats();
    } catch (e) {
      setState(() {
        _error = "Lỗi khi khởi tạo: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChats() async {
    try {
      final chats = await _chatService.loadChatsByUserId(myId!);
      setState(() {
        _chats = chats;
        _isLoading = false;
      });

      // Theo dõi thay đổi Realtime
      _chatService.subscribeToChats(myId!, (updatedChats) {
        setState(() {
          _chats = updatedChats;
        });
      });
    } catch (e) {
      setState(() {
        _error = "Lỗi khi tải danh sách chat: $e";
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    Supabase.instance.client.channel('public:conversations').unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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

    if (_error != null) {
      return Center(
        child: Text(
          "Lỗi: $_error",
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
        const Search(),
        const Divider(height: 0),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child:
                _chats.isEmpty
                    ? Center(
                      child: Text(
                        "Không có đoạn chat nào. Hãy bắt đầu một cuộc trò chuyện mới!\nMyId: $myId\nMyUsername: $myUsername",
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    )
                    : ListView.builder(
                      scrollDirection: Axis.vertical,
                      padding: const EdgeInsets.only(bottom: 10),
                      itemCount: _chats.length,
                      itemBuilder: (context, index) {
                        final chat = _chats[index];
                        final conversationId =
                            chat['conversation_id'] as String;
                        final friendId = chat['friend_id'] as String;
                        final alias = chat['friend_username'] as String;
                        final avatarUrl = chat['friend_avatar_url'] as String;
                        final lastMessage = chat['last_message'] as String;
                        final lastMessageTime =
                            chat['last_message_time'] as DateTime;
                        final isOnline = chat['friend_status'] == 'online';
                        final isSeen = chat['is_read'] as bool;

                        return ChatTitle(
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
                                    (context) => Messages(
                                      chatId: conversationId,
                                      myId: myId!,
                                      friendId: friendId,
                                      friendName: alias,
                                      friendImage: avatarUrl,
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
        ),
      ],
    );
  }
}
