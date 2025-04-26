import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/presentation/screens/messages_screen.dart';
import 'package:whisp/presentation/widgets/chat_title.dart';
import 'package:whisp/services/chat_service.dart';
import 'package:whisp/services/db_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

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

      final isOnline =
          await Connectivity().checkConnectivity() != ConnectivityResult.none;
      if (!isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang sử dụng dữ liệu cục bộ (offline)'),
          ),
        );
      }

      _chatService.subscribeToChats(myId!, (updatedChats) {
        // print('Chats updated via Realtime in Chats: $updatedChats');
        if (mounted) {
          setState(() {
            _chats = updatedChats;
          });
        }
      });
    } catch (e) {
      print('Error loading chats: $e');
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

    _chatService.updateChatReadStatus(myId!, conversationId).catchError((e) {
      print('Error updating chat read status: $e');
    });
  }

  Future<void> _deleteChat(String conversationId) async {
    try {
      await _chatService.deleteConversation(myId!, conversationId);
      setState(() {
        _chats.removeWhere((chat) => chat['conversation_id'] == conversationId);
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
        const Divider(height: 8),
        Expanded(
          child:
              _chats.isEmpty
                  ? const Center(
                    child: Text(
                      "Không có đoạn chat nào.\nHãy bắt đầu một cuộc trò chuyện mới!",
                      style: TextStyle(fontSize: 16),
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
                                        _deleteChat(conversationId);
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
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: double.infinity,
                              child: Divider(height: 8, thickness: 1),
                            ), // Divider kéo dài hết màn hình
                          ],
                        );
                      },
                    ),
                    onRefresh: () async {
                      await _loadChats();
                    },
                  ),
        ),
      ],
    );
  }
}
