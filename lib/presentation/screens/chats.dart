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
  String? myAvatarUrl;
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final SupabaseClient _supabase = Supabase.instance.client;

  final Map<String, Map<String, String>> _userInfoCache = {};
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
        print("Lỗi: Người dùng chưa đăng nhập.");
        setState(() {
          _error = "Người dùng chưa đăng nhập.";
          _isLoading = false;
        });
        return;
      }

      final userId = user.id;
      final userInfo = await _userService.getUserInfo(userId);
      final username = userInfo?['username'] as String? ?? userId;
      final avatarUrl = userInfo?['avatar_url'] as String? ?? 'https://via.placeholder.com/150';

      setState(() {
        myId = userId;
        myUsername = username;
        myAvatarUrl = avatarUrl;
        print("myId: $myId");
        print("myUsername: $myUsername");
        print("myAvatarUrl: $myAvatarUrl");
      });

      _loadChats();
    } catch (e) {
      print("Lỗi khi lấy thông tin người dùng: $e");
      setState(() {
        _error = "Lỗi khi lấy thông tin người dùng: $e";
        _isLoading = false;
      });
    }
  }

  Future<Map<String, String>> _getUserInfo(String userId) async {
    if (_userInfoCache.containsKey(userId)) {
      return _userInfoCache[userId]!;
    }
    final userInfo = await _userService.getUserInfo(userId);
    final name = userInfo?['username'] as String? ?? userId;
    final avatarUrl = userInfo?['avatar_url'] as String? ?? 'https://via.placeholder.com/150';
    final userData = {'username': name, 'avatar_url': avatarUrl};
    _userInfoCache[userId] = userData;
    return userData;
  }

  Future<void> _loadChats() async {
    _chatService.debugGetAllChats().then((allChats) {
      print("Debug: Tất cả đoạn chat trong bảng chats: $allChats");
    });

    try {
      final chats = await _chatService.loadChatsByUserId(myId!);

      final friendIds =
          chats
              .map((chat) {
                final participants = chat['participants'] as List<dynamic>;
                return participants.firstWhere((id) => id != myId) as String;
              })
              .toSet()
              .toList();

      for (final friendId in friendIds) {
        await _getUserInfo(friendId);
      }

      setState(() {
        _chats = chats;
        _isLoading = false;
      });

      _supabase
          .channel('public:chats')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'chats',
            callback: (payload) async {
              final updatedChats = await _chatService.loadChatsByUserId(myId!);

              final newFriendIds =
                  updatedChats
                      .map((chat) {
                        final participants = chat['participants'] as List<dynamic>;
                        return participants.firstWhere((id) => id != myId) as String;
                      })
                      .toSet()
                      .toList();

              for (final friendId in newFriendIds) {
                if (!_userInfoCache.containsKey(friendId)) {
                  await _getUserInfo(friendId);
                }
              }

              setState(() {
                _chats = updatedChats;
              });
            },
          )
          .subscribe();
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Đang tải thông tin người dùng...")]));
    }

    if (myId == null) {
      return Center(child: Text("Lỗi: Người dùng chưa đăng nhập. Vui lòng đăng nhập để tiếp tục.", style: TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center));
    }

    return Column(
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
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Đang tải danh sách đoạn chat...")]))
                    : _error != null
                    ? Center(child: Text("Lỗi: $_error", style: TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center))
                    : _chats.isEmpty
                    ? Center(child: Text("Không có đoạn chat nào. Hãy bắt đầu một cuộc trò chuyện mới! \n MyId: $myId \n MyUsername: $myUsername \n MyAvatarUrl: $myAvatarUrl", style: TextStyle(fontSize: 16), textAlign: TextAlign.center))
                    : ListView.builder(
                      scrollDirection: Axis.vertical,
                      padding: EdgeInsets.only(bottom: 10),
                      itemCount: _chats.length,
                      itemBuilder: (context, index) {
                        final chat = _chats[index];
                        final chatId = chat['id'];
                        final participants = chat['participants'] as List<dynamic>;
                        final friendId = participants.firstWhere((id) => id != myId);
                        final lastMessage = chat['last_message'] ?? "Chưa có tin nhắn";
                        final lastMessageTime = chat['last_message_time'] != null ? DateTime.parse(chat['last_message_time']) : DateTime.now();
                        final isOnline = chat['is_online'] ?? false;

                        // Placeholder cố định trong thời gian chờ dữ liệu
                        Widget placeholder = const SizedBox(
                          height: 72, // Chiều cao cố định để tránh layout shift
                          child: Center(child: CircularProgressIndicator()),
                        );

                        // Kiểm tra xem thông tin người dùng đã có trong cache chưa
                        if (!_userInfoCache.containsKey(friendId)) {
                          return FutureBuilder<Map<String, String>>(
                            future: _getUserInfo(friendId),
                            builder: (context, userSnapshot) {
                              if (userSnapshot.connectionState == ConnectionState.waiting) {
                                return placeholder;
                              }

                              if (userSnapshot.hasError) {
                                return ListTile(title: Text("Lỗi: ${userSnapshot.error}"), subtitle: Text(lastMessage));
                              }

                              if (!userSnapshot.hasData) {
                                return ListTile(title: Text(friendId), subtitle: Text(lastMessage));
                              }

                              final userInfo = userSnapshot.data!;
                              final friendName = userInfo['username']!;
                              final friendAvatarUrl = userInfo['avatar_url']!;

                              return FutureBuilder<bool>(
                                future: _chatService.hasUnreadMessages(chatId, myId!),
                                builder: (context, unreadSnapshot) {
                                  if (unreadSnapshot.connectionState == ConnectionState.waiting) {
                                    return placeholder;
                                  }

                                  if (unreadSnapshot.hasError) {
                                    return ListTile(title: Text(friendName), subtitle: Text("Lỗi: ${unreadSnapshot.error}"));
                                  }

                                  if (!unreadSnapshot.hasData) {
                                    return ListTile(title: Text(friendName), subtitle: Text(lastMessage));
                                  }

                                  final hasUnread = unreadSnapshot.data!;

                                  return ChatTitle(
                                    friendAvatarUrl,
                                    friendName,
                                    lastMessageTime,
                                    !hasUnread,
                                    isOnline,
                                    lastMessage,
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => Messages(chatId: chatId, myId: myId!, friendId: friendId, friendName: friendName, friendImage: friendAvatarUrl)));
                                    },
                                  );
                                },
                              );
                            },
                          );
                        }

                        // Nếu thông tin đã có trong cache, hiển thị ngay lập tức
                        final userInfo = _userInfoCache[friendId]!;
                        final friendName = userInfo['username']!;
                        final friendAvatarUrl = userInfo['avatar_url']!;

                        return FutureBuilder<bool>(
                          future: _chatService.hasUnreadMessages(chatId, myId!),
                          builder: (context, unreadSnapshot) {
                            if (unreadSnapshot.connectionState == ConnectionState.waiting) {
                              return placeholder;
                            }

                            if (unreadSnapshot.hasError) {
                              return ListTile(title: Text(friendName), subtitle: Text("Lỗi: ${unreadSnapshot.error}"));
                            }

                            if (!unreadSnapshot.hasData) {
                              return ListTile(title: Text(friendName), subtitle: Text(lastMessage));
                            }

                            final hasUnread = unreadSnapshot.data!;

                            return ChatTitle(
                              friendAvatarUrl,
                              friendName,
                              lastMessageTime,
                              !hasUnread,
                              isOnline,
                              lastMessage,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => Messages(chatId: chatId, myId: myId!, friendId: friendId, friendName: friendName, friendImage: friendAvatarUrl)));
                              },
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
