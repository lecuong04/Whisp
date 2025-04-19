import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/presentation/screens/messages.dart';
import 'package:whisp/presentation/widgets/chat_title.dart';
import 'package:whisp/presentation/widgets/search.dart';
import 'package:whisp/services/chat_service.dart';
import 'package:whisp/services/db_service.dart';

class Chats extends StatefulWidget {
  const Chats({super.key});

  @override
  State<StatefulWidget> createState() => ChatsState();
}

class ChatsState extends State<Chats> {
  String? myId;
  String? myFullName;
  final ChatService _chatService = ChatService();
  final DatabaseService _dbService = DatabaseService.instance;
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
      Map<String, dynamic>? userInfo;

      try {
        userInfo = await _chatService.getUserInfo(userId);
      } catch (e) {
        print('Error fetching user info: $e');
        // Nếu offline, dùng dữ liệu cục bộ
        userInfo = await _dbService.loadUser(userId);
        if (userInfo == null) {
          setState(() {
            _error =
                "Không thể lấy thông tin người dùng và không có dữ liệu cục bộ.";
            _isLoading = false;
          });
          return;
        }
      }

      final fullName = userInfo?['full_name'] as String? ?? 'User';

      setState(() {
        myId = userId;
        myFullName = fullName;
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
      print('Chats loaded in Chats: $_chats');

      // Theo dõi thay đổi Realtime
      _chatService.subscribeToChats(myId!, (updatedChats) {
        setState(() {
          _chats = updatedChats;
          print('Chats updated via Realtime in Chats: $_chats');
        });
      });
    } catch (e) {
      print('Error loading chats: $e');
      // Nếu offline, thử tải từ SQLite
      final localChats = await _dbService.loadChats(myId!);
      if (localChats.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang sử dụng dữ liệu cục bộ (offline)'),
          ),
        );
        setState(() {
          _chats = localChats;
          _isLoading = false;
        });
        print('Loaded ${localChats.length} chats from SQLite in offline mode');
      } else {
        setState(() {
          _error = "Không có mạng và không có chat cục bộ: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _updateChatReadStatus(String conversationId) {
    setState(() {
      _chats =
          _chats.map((chat) {
            if (chat['conversation_id'] == conversationId) {
              return {...chat, 'is_read': true};
            }
            return chat;
          }).toList();
      print('Updated local is_read for $conversationId: $_chats');
    });

    // Cập nhật SQLite
    _chatService.updateChatReadStatus(myId!, conversationId).catchError((e) {
      print('Error updating chat read status: $e');
    });
  }

  @override
  void dispose() {
    Supabase.instance.client.channel('public:chats').unsubscribe();
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
                        "Không có đoạn chat nào. Hãy bắt đầu một cuộc trò chuyện mới!\nMyId: $myId\nMyFullName: $myFullName",
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
                        final alias = chat['friend_full_name'] as String;
                        final avatarUrl = chat['friend_avatar_url'] as String;
                        final lastMessage = chat['last_message'] as String;
                        final lastMessageTime =
                            chat['last_message_time'] as DateTime;
                        final isOnline = chat['friend_status'] == 'online';
                        final isSeen = chat['is_read'] as bool;
                        print(
                          'Chat: $conversationId, FriendId: $friendId, Alias: $alias, LastMessage: $lastMessage, LastMessageTime: $lastMessageTime, IsOnline: $isOnline, IsSeen: $isSeen',
                        );
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
                            ).then((result) {
                              if (result != null &&
                                  result['conversation_id'] != null) {
                                _updateChatReadStatus(
                                  result['conversation_id'],
                                );
                              }
                            });
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
