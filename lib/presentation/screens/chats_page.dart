import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/presentation/screens/messages_screen.dart';
import 'package:whisp/presentation/widgets/chat_title.dart';
import 'package:whisp/services/chat_service.dart';
import 'package:whisp/services/db_service.dart';

class Chats extends StatefulWidget {
  const Chats({super.key});

  @override
  State<StatefulWidget> createState() => _ChatsState();
}

class _ChatsState extends State<Chats>
    with AutomaticKeepAliveClientMixin<Chats> {
  @override
  bool get wantKeepAlive => true;

  String? myId;
  String? myFullName;
  final ChatService _chatService = ChatService();
  final DatabaseService _dbService = DatabaseService.instance;
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _chatChannel;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _error = "Người dùng chưa đăng nhập.";
        _isLoading = false;
      });
      return;
    }
    try {
      final userId = user.id;
      Map<String, dynamic>? userInfo;

      try {
        userInfo = await _chatService.getUserInfo(userId);
      } catch (e) {
        print('Error fetching user info: $e');
        userInfo = await _dbService.loadUser(userId);
      }

      // Nếu không có thông tin người dùng, dùng mặc định
      final fullName = userInfo?['full_name'] as String? ?? 'User';

      setState(() {
        myId = userId;
        myFullName = fullName;
      });

      await _loadChats();
    } catch (e) {
      _error = "Lỗi khi khởi tạo: $e";
      _isLoading = false;
      setState(() {});
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

      // Nếu offline, hiển thị thông báo
      final isOnline =
          await Connectivity().checkConnectivity() != ConnectivityResult.none;
      if (!isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang sử dụng dữ liệu cục bộ (offline)'),
          ),
        );
      }

      // Theo dõi thay đổi Realtime
      _chatService.subscribeToChats(myId!, (updatedChats) {
        print('Chats updated via Realtime in Chats: $_chats');
        if (mounted) {
          setState(() {
            _chats = updatedChats;
          });
        }
      });
    } catch (e) {
      print('Error loading chats: $e');
      // Tải dữ liệu cục bộ
      final localChats = await _dbService.loadChats(myId!);
      setState(() {
        _chats = localChats;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang sử dụng dữ liệu cục bộ (offline)')),
      );
      print('Loaded ${localChats.length} chats from SQLite in offline mode');
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
    if (_chatChannel != null) {
      Supabase.instance.client.removeChannel(_chatChannel!);
      _chatChannel = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
        const Divider(height: 1),
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
                    : RefreshIndicator(
                      child: ListView.builder(
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
                                        contactId: friendId,
                                        contactName: alias,
                                        contactImage: avatarUrl,
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
                      onRefresh: () async {
                        await _loadChats();
                      },
                    ),
          ),
        ),
      ],
    );
  }
}
