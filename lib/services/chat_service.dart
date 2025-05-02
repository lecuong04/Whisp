import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/utils/constants.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  // final DatabaseService _dbService = DatabaseService.instance; // Comment giữ lại từ SQLite

  Future<bool> _isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  Future<List<Map<String, dynamic>>> loadChatsByUserId(String userId) async {
    try {
      // final localChats = await _dbService.loadChats(userId); // Comment giữ lại từ SQLite
      if (!(await _isOnline())) {
        print('Offline: Returning local chats for user $userId');
        // return localChats; // Comment giữ lại từ SQLite
        throw Exception('Không có kết nối mạng');
      }

      final response = await _supabase
          .from('conversation_participants')
          .select('''
            conversation_id,
            conversations!inner(
              id,
              name,
              is_group,
              created_at,
              created_by
            )
          ''')
          .eq('user_id', userId)
          .eq('conversations.is_group', false)
          .eq('is_deleted', false);

      final List<Map<String, dynamic>> userChats = response;

      final processedChats = <Map<String, dynamic>>[];
      for (var chat in userChats) {
        final conversationId = chat['conversation_id'];
        print('Processing conversation: $conversationId');

        final friendResponse =
            await _supabase
                .from('conversation_participants')
                .select(
                  'user_id, users!inner(id, full_name, avatar_url, status)',
                )
                .eq('conversation_id', conversationId)
                .neq('user_id', userId)
                .eq('is_deleted', false)
                .limit(1) // Đảm bảo chỉ lấy 1 bản ghi
                .single();

        if (friendResponse == null) {
          print('No friend found for conversation: $conversationId');
          continue;
        }

        final friend = friendResponse['users'] as Map<String, dynamic>;
        // await _dbService.saveUser(friend); // Comment giữ lại từ SQLite

        final lastMessage =
            await _supabase
                .from('messages')
                .select('id, content, sent_at')
                .eq('conversation_id', conversationId)
                .order('sent_at', ascending: false)
                .limit(1)
                .maybeSingle();

        bool isRead = true;
        if (lastMessage != null) {
          final lastMessageStatus =
              await _supabase
                  .from('message_statuses')
                  .select('is_read')
                  .eq('message_id', lastMessage['id'])
                  .eq('user_id', userId)
                  .maybeSingle();
          isRead = lastMessageStatus?['is_read'] ?? true;
          print(
            'Last message for $conversationId: ${lastMessage['content']}, sent_at: ${lastMessage['sent_at']}, is_read: $isRead',
          );
        } else {
          print('No messages for $conversationId');
          continue;
        }

        final lastMessageTime =
            DateTime.parse(lastMessage['sent_at']).toLocal();

        processedChats.add({
          'conversation_id': conversationId,
          'friend_id': friend['id'],
          'friend_full_name': friend['full_name'] ?? 'Unknown',
          'friend_avatar_url': friend['avatar_url'] ?? '',
          'friend_status': friend['status'] ?? 'offline',
          'last_message': lastMessage['content'] ?? 'Chưa có tin nhắn',
          'last_message_time': lastMessageTime,
          'is_read': isRead,
          'is_group': chat['conversations']['is_group'],
        });
      }

      processedChats.sort(
        (a, b) => b['last_message_time'].compareTo(a['last_message_time']),
      );
      print('Processed chats: $processedChats');

      // if (processedChats.isNotEmpty) {
      //   await _dbService.saveChats(userId, processedChats); // Comment giữ lại từ SQLite
      // }

      return processedChats;
    } catch (e) {
      print('Error loading chats: $e');
      // final localChats = await _dbService.loadChats(userId); // Comment giữ lại từ SQLite
      // print(
      //   'Offline: Returning ${localChats.length} local chats for user $userId',
      // ); // Comment giữ lại từ SQLite
      // return localChats; // Comment giữ lại từ SQLite
      throw Exception('Lỗi khi tải danh sách chat: $e');
    }
  }

  // Future<Map<String, dynamic>> createDirectConversation({
  //   required String userId1,
  //   required String userId2,
  // }) async {
  //   try {
  //     final existingConversation =
  //         await _supabase
  //             .from('conversation_participants')
  //             .select('conversation_id')
  //             .eq('user_id', userId1)
  //             .eq('is_deleted', false)
  //             .inFilter(
  //               'conversation_id',
  //               await _supabase
  //                   .from('conversation_participants')
  //                   .select('conversation_id')
  //                   .eq('user_id', userId2)
  //                   .eq('conversations.is_group', false),
  //             )
  //             .maybeSingle();

  //     if (existingConversation != null) {
  //       final conversationId = existingConversation['conversation_id'];
  //       print('Existing conversation found: $conversationId');
  //       return {'conversation_id': conversationId};
  //     }

  //     final conversationResponse =
  //         await _supabase
  //             .from('conversations')
  //             .insert({'name': null, 'is_group': false, 'created_by': userId1})
  //             .select('id')
  //             .single();

  //     final conversationId = conversationResponse['id'];
  //     print('New conversation created: $conversationId');

  //     await _supabase.from('conversation_participants').insert([
  //       {'conversation_id': conversationId, 'user_id': userId1},
  //       {'conversation_id': conversationId, 'user_id': userId2},
  //     ]);

  //     // final chats = await loadChatsByUserId(userId1); // Comment giữ lại từ SQLite
  //     // await _dbService.saveChats(userId1, chats); // Comment giữ lại từ SQLite

  //     return {'conversation_id': conversationId};
  //   } catch (e) {
  //     print('Error creating conversation: $e');
  //     throw Exception('Lỗi khi tạo cuộc trò chuyện: $e');
  //   }
  // }

  Future<void> markChatAsDeleted(String userId, String conversationId) async {
    try {
      if (!(await _isOnline())) {
        throw Exception('Cần kết nối mạng để xóa cuộc trò chuyện');
      }

      await _supabase
          .from('conversation_participants')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);

      // await _dbService.deleteMessages(conversationId); // Comment giữ lại từ SQLite
      // await _dbService.deleteChats(userId); // Comment giữ lại từ SQLite
      // final updatedChats = await loadChatsByUserId(userId); // Comment giữ lại từ SQLite
      // await _dbService.saveChats(userId, updatedChats); // Comment giữ lại từ SQLite

      print('Marked conversation $conversationId as deleted for user $userId');
    } catch (e) {
      print('Error marking conversation as deleted: $e');
      throw Exception('Lỗi khi xóa cuộc trò chuyện: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      // final localUser = await _dbService.loadUser(userId); // Comment giữ lại từ SQLite
      // if (localUser != null) { // Comment giữ lại từ SQLite
      //   return localUser; // Comment giữ lại từ SQLite
      // } // Comment giữ lại từ SQLite

      if (!(await _isOnline())) {
        print('Offline: No local user data for userId $userId');
        return null;
      }

      final response =
          await _supabase
              .from('users')
              .select('id, full_name, avatar_url, status')
              .eq('id', userId)
              .maybeSingle();

      // if (response != null) { // Comment giữ lại từ SQLite
      //   await _dbService.saveUser(response); // Comment giữ lại từ SQLite
      // } // Comment giữ lại từ SQLite

      return response;
    } catch (e) {
      print('Error fetching user info: $e');
      // final localUser = await _dbService.loadUser(userId); // Comment giữ lại từ SQLite
      // return localUser; // Comment giữ lại từ SQLite
      throw Exception('Lỗi khi tải thông tin người dùng: $e');
    }
  }

  void subscribeToChats(
    String userId,
    Function(List<Map<String, dynamic>>) onUpdate,
  ) {
    final channel = _supabase.channel('public:chats:$userId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            try {
              final newMessage = payload.newRecord;
              final conversationId = newMessage['conversation_id'] as String;

              // Kiểm tra xem cuộc trò chuyện có phải là 1-1 không
              final conversation =
                  await _supabase
                      .from('conversations')
                      .select('is_group')
                      .eq('id', conversationId)
                      .single();

              if (conversation['is_group'] == true) {
                print('Skipping group conversation: $conversationId');
                return;
              }

              final lastMessage =
                  await _supabase
                      .from('messages')
                      .select('id, content, sent_at')
                      .eq('conversation_id', conversationId)
                      .order('sent_at', ascending: false)
                      .limit(1)
                      .maybeSingle();

              if (lastMessage == null) {
                print('No last message found for conversation $conversationId');
                return;
              }

              final friendResponse =
                  await _supabase
                      .from('conversation_participants')
                      .select(
                        'user_id, users!inner(id, full_name, avatar_url, status)',
                      )
                      .eq('conversation_id', conversationId)
                      .neq('user_id', userId)
                      .eq('is_deleted', false)
                      .limit(1) // Đảm bảo chỉ lấy 1 bản ghi
                      .single();

              if (friendResponse == null) {
                print('No friend found for conversation $conversationId');
                return;
              }

              final friend = friendResponse['users'] as Map<String, dynamic>;
              // await _dbService.saveUser(friend); // Comment giữ lại từ SQLite

              final lastMessageStatus =
                  await _supabase
                      .from('message_statuses')
                      .select('is_read')
                      .eq('message_id', lastMessage['id'])
                      .eq('user_id', userId)
                      .maybeSingle();
              final isRead = lastMessageStatus?['is_read'] ?? true;

              final updatedChat = {
                'conversation_id': conversationId,
                'friend_id': friend['id'],
                'friend_full_name': friend['full_name'] ?? 'Unknown',
                'friend_avatar_url': friend['avatar_url'] ?? '',
                'friend_status': friend['status'] ?? 'offline',
                'last_message': lastMessage['content'] ?? 'Chưa có tin nhắn',
                'last_message_time':
                    DateTime.parse(lastMessage['sent_at']).toLocal(),
                'is_read': isRead,
                'is_group': false,
              };

              // Tải lại toàn bộ danh sách chat để đảm bảo nhất quán
              final currentChats = await loadChatsByUserId(userId);
              final updatedChats = [...currentChats];
              final chatIndex = updatedChats.indexWhere(
                (chat) => chat['conversation_id'] == conversationId,
              );

              if (chatIndex >= 0) {
                updatedChats[chatIndex] = updatedChat;
              } else {
                updatedChats.add(updatedChat);
              }

              updatedChats.sort(
                (a, b) =>
                    b['last_message_time'].compareTo(a['last_message_time']),
              );

              // await _dbService.saveChats(userId, updatedChats); // Comment giữ lại từ SQLite
              if (updatedChats.isNotEmpty) {
                onUpdate(updatedChats);
              }
            } catch (e) {
              print('Error processing message insert event: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'message_statuses',
          callback: (payload) async {
            try {
              final messageId = payload.newRecord['message_id'] as String;
              final isRead = payload.newRecord['is_read'] as bool;

              final message =
                  await _supabase
                      .from('messages')
                      .select('conversation_id')
                      .eq('id', messageId)
                      .single();

              final conversationId = message['conversation_id'] as String;

              // Tải lại danh sách chat để cập nhật trạng thái is_read
              final currentChats = await loadChatsByUserId(userId);
              final updatedChats =
                  currentChats.map((chat) {
                    if (chat['conversation_id'] == conversationId) {
                      return {...chat, 'is_read': isRead};
                    }
                    return chat;
                  }).toList();

              // await _dbService.saveChats(userId, updatedChats); // Comment giữ lại từ SQLite
              if (updatedChats.isNotEmpty) {
                onUpdate(updatedChats);
              }
            } catch (e) {
              print('Error processing message_statuses update event: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          callback: (payload) async {
            try {
              final user = payload.newRecord;
              // await _dbService.saveUser(user); // Comment giữ lại từ SQLite

              // Tải lại danh sách chat để cập nhật thông tin người dùng
              final currentChats = await loadChatsByUserId(userId);
              final updatedChats =
                  currentChats.map((chat) {
                    if (chat['friend_id'] == user['id']) {
                      return {
                        ...chat,
                        'friend_full_name':
                            user['full_name'] ?? chat['friend_full_name'],
                        'friend_avatar_url':
                            user['avatar_url'] ?? chat['friend_avatar_url'],
                        'friend_status':
                            user['status'] ?? chat['friend_status'],
                      };
                    }
                    return chat;
                  }).toList();

              // await _dbService.saveChats(userId, updatedChats); // Comment giữ lại từ SQLite
              if (updatedChats.isNotEmpty) {
                onUpdate(updatedChats);
              }
            } catch (e) {
              print('Error processing users update event: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversation_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            try {
              // Tải lại danh sách chat khi is_deleted thay đổi
              final updatedChats = await loadChatsByUserId(userId);
              if (updatedChats.isNotEmpty) {
                onUpdate(updatedChats);
              }
            } catch (e) {
              print(
                'Error processing conversation_participants update event: $e',
              );
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            print('Subscribed to chats for user $userId');
          } else if (status == RealtimeSubscribeStatus.closed) {
            print('Unsubscribed from chats for user $userId');
          } else if (error != null) {
            print('Error subscribing to chats: $error');
          }
        });
  }

  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      if (!(await _isOnline())) {
        throw Exception('Không có kết nối mạng');
      }

      final messageResponse =
          await _supabase
              .from('messages')
              .insert({
                'conversation_id': conversationId,
                'sender_id': senderId,
                'content': content,
                'message_type': messageType,
              })
              .select('''
            id, conversation_id, sender_id, content, sent_at, message_type,
            users!sender_id(id, full_name, avatar_url, status),
            message_statuses(user_id, is_read, read_at)
          ''')
              .single();

      final messageId = messageResponse['id'];
      print('Sent message: $messageId');

      // await _dbService.saveMessages(conversationId, [messageResponse]); // Comment giữ lại từ SQLite
      // if (messageResponse['users'] != null) { // Comment giữ lại từ SQLite
      //   await _dbService.saveUser(messageResponse['users']); // Comment giữ lại từ SQLite
      // } // Comment giữ lại từ SQLite

      return messageResponse;
    } catch (e) {
      print('Error sending message: $e');
      throw Exception('Lỗi khi gửi tin nhắn: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadMessages(
    String conversationId, {
    int limit = MESSAGE_PAGE_SIZE,
    String? beforeSentAt,
  }) async {
    try {
      if (!(await _isOnline())) {
        // final localMessages = await _dbService.loadMessages( // Comment giữ lại từ SQLite
        //   conversationId, // Comment giữ lại từ SQLite
        //   limit: limit, // Comment giữ lại từ SQLite
        //   beforeSentAt: beforeSentAt, // Comment giữ lại từ SQLite
        // ); // Comment giữ lại từ SQLite
        // print( // Comment giữ lại từ SQLite
        //   'Offline: Returning ${localMessages.length} local messages for conversation $conversationId', // Comment giữ lại từ SQLite
        // ); // Comment giữ lại từ SQLite
        // return localMessages; // Comment giữ lại từ SQLite
        throw Exception('Không có kết nối mạng');
      }

      final participant =
          await _supabase
              .from('conversation_participants')
              .select('deleted_at')
              .eq('conversation_id', conversationId)
              .eq('user_id', _supabase.auth.currentUser!.id)
              .maybeSingle();

      var query = _supabase
          .from('messages')
          .select('''
            id, conversation_id, sender_id, content, sent_at, message_type,
            users!sender_id(id, full_name, avatar_url, status),
            message_statuses(user_id, is_read, read_at)
          ''')
          .eq('conversation_id', conversationId);

      if (beforeSentAt != null) {
        query = query.lt('sent_at', beforeSentAt);
      }

      if (participant != null && participant['deleted_at'] != null) {
        query = query.gt('sent_at', participant['deleted_at']);
      }

      final messages = await query
          .order('sent_at', ascending: false)
          .limit(limit);

      print(
        'Loaded ${messages.length} messages from Supabase for conversation $conversationId${beforeSentAt != null ? ' before $beforeSentAt' : ''}',
      );

      // if (messages.isNotEmpty) { // Comment giữ lại từ SQLite
      //   await _dbService.saveMessages(conversationId, messages); // Comment giữ lại từ SQLite
      //   for (var message in messages) { // Comment giữ lại từ SQLite
      //     if (message['users'] != null) { // Comment giữ lại từ SQLite
      //       await _dbService.saveUser(message['users']); // Comment giữ lại từ SQLite
      //     } // Comment giữ lại từ SQLite
      //   } // Comment giữ lại từ SQLite
      // } // Comment giữ lại từ SQLite

      return messages;
    } catch (e) {
      print('Error loading messages: $e');
      // final localMessages = await _dbService.loadMessages( // Comment giữ lại từ SQLite
      //   conversationId, // Comment giữ lại từ SQLite
      //   limit: limit, // Comment giữ lại từ SQLite
      //   beforeSentAt: beforeSentAt, // Comment giữ lại từ SQLite
      // ); // Comment giữ lại từ SQLite
      // print( // Comment giữ lại từ SQLite
      //   'Error/Offline: Returning ${localMessages.length} local messages for conversation $conversationId', // Comment giữ lại từ SQLite
      // ); // Comment giữ lại từ SQLite
      // return localMessages; // Comment giữ lại từ SQLite
      throw Exception('Lỗi khi tải tin nhắn: $e');
    }
  }

  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      if (!(await _isOnline())) {
        print(
          'Offline: Cannot mark messages as read for conversation $conversationId',
        );
        return;
      }

      final messageIds = await _supabase
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId);

      final statuses = await _supabase
          .from('message_statuses')
          .select('message_id, user_id, is_read')
          .eq('user_id', _supabase.auth.currentUser!.id)
          .inFilter('message_id', messageIds.map((m) => m['id']).toList());

      final unreadMessageIds =
          statuses
              .where((status) => status['is_read'] == false)
              .map((status) => status['message_id'])
              .toList();

      if (unreadMessageIds.isNotEmpty) {
        await _supabase
            .from('message_statuses')
            .update({
              'is_read': true,
              'read_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', _supabase.auth.currentUser!.id)
            .inFilter('message_id', unreadMessageIds);
        print(
          'Marked ${unreadMessageIds.length} messages as read for conversation $conversationId',
        );

        // final messages = await loadMessages(conversationId); // Comment giữ lại từ SQLite
        // await _dbService.saveMessages(conversationId, messages); // Comment giữ lại từ SQLite
      }
    } catch (e) {
      print('Error marking messages as read: $e');
      throw Exception('Lỗi khi đánh dấu tin nhắn đã đọc: $e');
    }
  }

  RealtimeChannel? _messageChannel;

  void subscribeToMessages(
    String conversationId,
    Function(List<Map<String, dynamic>>) onUpdate,
  ) {
    if (_messageChannel != null) {
      _supabase.removeChannel(_messageChannel!);
    }

    _messageChannel = _supabase.channel('messages:$conversationId');

    _messageChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            final newMessage = payload.newRecord;

            final message =
                await _supabase
                    .from('messages')
                    .select('''
                  id, conversation_id, sender_id, content, sent_at, message_type,
                  users!sender_id(id, full_name, avatar_url, status),
                  message_statuses(user_id, is_read, read_at)
                ''')
                    .eq('id', newMessage['id'])
                    .single();

            // await _dbService.saveMessages(conversationId, [message]); // Comment giữ lại từ SQLite
            // if (message['users'] != null) { // Comment giữ lại từ SQLite
            //   await _dbService.saveUser(message['users']); // Comment giữ lại từ SQLite
            // } // Comment giữ lại từ SQLite

            onUpdate([message]);
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            print('Subscribed to messages for conversation $conversationId');
          } else if (status == RealtimeSubscribeStatus.closed) {
            print(
              'Unsubscribed from messages for conversation $conversationId',
            );
          } else if (error != null) {
            print('Error subscribing to messages: $error');
          }
        });
  }

  void unsubscribeMessages() {
    if (_messageChannel != null) {
      _supabase.removeChannel(_messageChannel!);
      _messageChannel = null;
      print('Unsubscribed from all message channels');
    }
  }

  Future<void> updateChatReadStatus(
    String userId,
    String conversationId,
  ) async {
    try {
      // final chats = await loadChatsByUserId(userId); // Comment giữ lại từ SQLite
      // final updatedChats = chats.map((chat) { // Comment giữ lại từ SQLite
      //   if (chat['conversation_id'] == conversationId) { // Comment giữ lại từ SQLite
      //     return {...chat, 'is_read': true}; // Comment giữ lại từ SQLite
      //   } // Comment giữ lại từ SQLite
      //   return chat; // Comment giữ lại từ SQLite
      // }).toList(); // Comment giữ lại từ SQLite
      // await _dbService.saveChats(userId, updatedChats); // Comment giữ lại từ SQLite
      print('Updated is_read for conversation $conversationId');
    } catch (e) {
      print('Error updating chat read status: $e');
      throw Exception('Lỗi khi cập nhật trạng thái chat: $e');
    }
  }

  Future<String> getDirectConversation(String friendId) async {
    var data = await _supabase.rpc(
      "get_direct_conversation",
      params: {
        "user_id1": _supabase.auth.currentUser!.id,
        "user_id2": friendId,
      },
    );
    return data.toString();
  }

  Future<Map<String, dynamic>> getConversationInfo(
    String conversationId,
  ) async {
    try {
      return await _supabase
          .rpc(
            "get_conversation_info",
            params: {
              "_conversation_id": conversationId,
              "_user_id": _supabase.auth.currentUser!.id,
            },
          )
          .single();
    } catch (e) {
      print(e);
      return <String, dynamic>{};
    }
  }
}
