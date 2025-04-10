import 'package:flutter/material.dart';
import 'package:whisp/presentation/screens/messages.dart';
import 'package:whisp/presentation/widgets/chat_title.dart';
import 'package:whisp/presentation/widgets/search.dart';
import 'package:whisp/services/chat_service.dart';
import 'package:whisp/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Chats extends StatefulWidget {
  const Chats({super.key});

  @override
  State<StatefulWidget> createState() => ChatsState();
}

class ChatsState extends State<Chats> {
  String? myId;
  String? myUsername;
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final SupabaseClient _supabase = Supabase.instance.client;

  final Map<String, String> _userNameCache = {};
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
      // Lấy thông tin người dùng hiện tại
      final userResponse = await _supabase.auth.getUser();
      final user = userResponse.user;

      if (user == null) {
        print("Lỗi: Người dùng chưa đăng nhập.");
        setState(() {
          _error = "Người dùng chưa đăng nhập.";
          _isLoading = false;
        });
        return;
      }

      // Lấy userId
      final userId = user.id;

      // Lấy username từ auth.users
      final userInfo = await _userService.getUserInfo(userId);
      final username = userInfo?['username'] as String? ?? userId;

      setState(() {
        myId = userId;
        myUsername = username;
        print("myId: $myId");
        print("myUsername: $myUsername");
      });

      // Tải danh sách đoạn chat
      _loadChats();
    } catch (e) {
      print("Lỗi khi lấy thông tin người dùng: $e");
      setState(() {
        _error = "Lỗi khi lấy thông tin người dùng: $e";
        _isLoading = false;
      });
    }
  }

  Future<String> _getUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }
    final userInfo = await _userService.getUserInfo(userId);
    final name = userInfo?['username'] as String? ?? userId;
    _userNameCache[userId] = name;
    return name;
  }

  void _loadChats() {
    // Debug: Lấy tất cả dữ liệu trong bảng chats
    _chatService.debugGetAllChats().then((allChats) {
      print("Debug: Tất cả đoạn chat trong bảng chats: $allChats");
    });

    // Lấy dữ liệu ban đầu
    _chatService
        .loadChatsByUserId(myId!)
        .then((chats) {
          setState(() {
            _chats = chats;
            _isLoading = false;
          });
        })
        .catchError((error) {
          setState(() {
            _error = error.toString();
            _isLoading = false;
          });
        });

    // Lắng nghe thay đổi Realtime cho bảng chats
    _supabase
        .channel('public:chats')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (payload) {
            // Khi có thay đổi, tải lại danh sách đoạn chat
            _chatService.loadChatsByUserId(myId!).then((chats) {
              setState(() {
                _chats = chats;
              });
            });
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("Đang tải thông tin người dùng..."),
            ],
          ),
        ),
      );
    }

    if (myId == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Lỗi: Người dùng chưa đăng nhập. Vui lòng đăng nhập để tiếp tục.",
            style: TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Search(),
          Divider(height: 0),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child:
                  _isLoading
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 10),
                            Text("Đang tải danh sách đoạn chat..."),
                          ],
                        ),
                      )
                      : _error != null
                      ? Center(
                        child: Text(
                          "Lỗi: $_error",
                          style: TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      )
                      : _chats.isEmpty
                      ? Center(
                        child: Text(
                          "Không có đoạn chat nào. Hãy bắt đầu một cuộc trò chuyện mới! \n MyId: $myId \n MyUsername: $myUsername",
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      )
                      : ListView.builder(
                        scrollDirection: Axis.vertical,
                        padding: EdgeInsets.only(bottom: 10),
                        itemCount: _chats.length,
                        itemBuilder: (context, index) {
                          final chat = _chats[index];
                          final chatId = chat['id'];
                          final participants =
                              chat['participants'] as List<dynamic>;
                          final friendId = participants.firstWhere(
                            (id) => id != myId,
                          );
                          final lastMessage =
                              chat['last_message'] ?? "Chưa có tin nhắn";
                          final lastMessageTime =
                              chat['last_message_time'] != null
                                  ? DateTime.parse(chat['last_message_time'])
                                  : DateTime.now();
                          final isOnline = chat['is_online'] ?? false;

                          return FutureBuilder<String>(
                            future: _getUserName(friendId),
                            builder: (context, userSnapshot) {
                              if (userSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return ListTile(
                                  title: Text("Đang tải..."),
                                  subtitle: Text(lastMessage),
                                );
                              }

                              if (userSnapshot.hasError) {
                                return ListTile(
                                  title: Text("Lỗi: ${userSnapshot.error}"),
                                  subtitle: Text(lastMessage),
                                );
                              }

                              if (!userSnapshot.hasData) {
                                return ListTile(
                                  title: Text(friendId),
                                  subtitle: Text(lastMessage),
                                );
                              }

                              final friendName = userSnapshot.data!;
                              const defaultProfilePicture =
                                  "https://via.placeholder.com/150";

                              return FutureBuilder<bool>(
                                future: _chatService.hasUnreadMessages(
                                  chatId,
                                  myId!,
                                ),
                                builder: (context, unreadSnapshot) {
                                  if (unreadSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return ListTile(
                                      title: Text(friendName),
                                      subtitle: Text(lastMessage),
                                    );
                                  }

                                  if (unreadSnapshot.hasError) {
                                    return ListTile(
                                      title: Text(friendName),
                                      subtitle: Text(
                                        "Lỗi: ${unreadSnapshot.error}",
                                      ),
                                    );
                                  }

                                  if (!unreadSnapshot.hasData) {
                                    return ListTile(
                                      title: Text(friendName),
                                      subtitle: Text(lastMessage),
                                    );
                                  }

                                  final hasUnread = unreadSnapshot.data!;

                                  return ChatTitle(
                                    defaultProfilePicture,
                                    friendName,
                                    lastMessageTime,
                                    !hasUnread,
                                    isOnline,
                                    lastMessage,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => Messages(
                                                chatId: chatId,
                                                myId: myId!,
                                                friendId: friendId,
                                                friendName: friendName,
                                                friendImage:
                                                    defaultProfilePicture,
                                              ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
