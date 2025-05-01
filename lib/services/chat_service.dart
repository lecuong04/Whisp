import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/services/db_service.dart';
import 'package:whisp/utils/constants.dart'; // Import constants.dart

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService.instance;

  Future<bool> _isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<List<Map<String, dynamic>>> loadChatsByUserId(String userId) async {
    try {
      final localChats = await _dbService.loadChats(userId);
      if (!(await _isOnline())) {
        print(
          'Offline: Returning ${localChats.length} local chats for user $userId',
        );
        return localChats;
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
          .eq('conversations.is_group', false);

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
                .maybeSingle();

        if (friendResponse == null) {
          print('No friend found for conversation: $conversationId');
          continue;
        }

        final friend = friendResponse['users'] as Map<String, dynamic>;
        await _dbService.saveUser(friend);

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

      if (processedChats.isNotEmpty) {
        await _dbService.saveChats(userId, processedChats);
      }

      return processedChats;
    } catch (e) {
      print('Error loading chats: $e');
      final localChats = await _dbService.loadChats(userId);
      print(
        'Offline: Returning ${localChats.length} local chats for user $userId',
      );
      return localChats;
    }
  }

  Future<Map<String, dynamic>> createDirectConversation({
    required String userId1,
    required String userId2,
  }) async {
    try {
      final existingConversation =
          await _supabase
              .from('conversation_participants')
              .select('conversation_id')
              .eq('user_id', userId1)
              .inFilter(
                'conversation_id',
                await _supabase
                    .from('conversation_participants')
                    .select('conversation_id')
                    .eq('user_id', userId2)
                    .eq('conversations.is_group', false),
              )
              .maybeSingle();

      if (existingConversation != null) {
        final conversationId = existingConversation['conversation_id'];
        print('Existing conversation found: $conversationId');
        return {'conversation_id': conversationId};
      }

      final conversationResponse =
          await _supabase
              .from('conversations')
              .insert({'name': null, 'is_group': false, 'created_by': userId1})
              .select('id')
              .single();

      final conversationId = conversationResponse['id'];
      print('New conversation created: $conversationId');

      await _supabase.from('conversation_participants').insert([
        {'conversation_id': conversationId, 'user_id': userId1},
        {'conversation_id': conversationId, 'user_id': userId2},
      ]);

      final chats = await loadChatsByUserId(userId1);
      await _dbService.saveChats(userId1, chats);

      return {'conversation_id': conversationId};
    } catch (e) {
      print('Error creating conversation: $e');
      throw Exception('Lỗi khi tạo cuộc trò chuyện: $e');
    }
  }

  Future<void> deleteConversation(String userId, String conversationId) async {
    try {
      if (!(await _isOnline())) {
        throw Exception('Cần kết nối mạng để xóa cuộc trò chuyện');
      }

      await _supabase.from('conversations').delete().eq('id', conversationId);

      await _dbService.deleteMessages(conversationId);
      await _dbService.deleteChats(userId);
      final updatedChats = await loadChatsByUserId(userId);
      await _dbService.saveChats(userId, updatedChats);

      print('Deleted conversation $conversationId for user $userId');
    } catch (e) {
      print('Error deleting conversation: $e');
      throw Exception('Lỗi khi xóa cuộc trò chuyện: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final localUser = _dbService.loadUser(userId);
      if (localUser != null) {
        return localUser;
      }

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

      if (response != null) {
        await _dbService.saveUser(response);
      }

      return response;
    } catch (e) {
      print('Error fetching user info: $e');
      final localUser = await _dbService.loadUser(userId);
      return localUser;
    }
  }

  void subscribeToChats(
    String userId,
    Function(List<Map<String, dynamic>>) onUpdate,
  ) {
    final channel = _supabase.channel('public:chats');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final newMessage = payload.newRecord;
            final conversationId = newMessage['conversation_id'] as String;

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
                (await _supabase
                    .from('conversation_participants')
                    .select(
                      'user_id, users!inner(id, full_name, avatar_url, status)',
                    )
                    .eq('conversation_id', conversationId)
                    .neq('user_id', userId)).firstOrNull;

            if (friendResponse == null) {
              print('No friend found for conversation $conversationId');
              return;
            }

            final friend = friendResponse['users'] as Map<String, dynamic>;
            await _dbService.saveUser(friend);

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

            final currentChats = await _dbService.loadChats(userId);
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

            await _dbService.saveChats(userId, updatedChats);
            onUpdate(updatedChats);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'message_statuses',
          callback: (payload) async {
            final messageId = payload.newRecord['message_id'] as String;
            final isRead = payload.newRecord['is_read'] as bool;

            final message =
                await _supabase
                    .from('messages')
                    .select('conversation_id')
                    .eq('id', messageId)
                    .single();

            final conversationId = message['conversation_id'] as String;

            final currentChats = await _dbService.loadChats(userId);
            final updatedChats =
                currentChats.map((chat) {
                  if (chat['conversation_id'] == conversationId) {
                    return {...chat, 'is_read': isRead};
                  }
                  return chat;
                }).toList();

            await _dbService.saveChats(userId, updatedChats);
            onUpdate(updatedChats);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          callback: (payload) async {
            final user = payload.newRecord;
            await _dbService.saveUser(user);

            final currentChats = await _dbService.loadChats(userId);
            final updatedChats =
                currentChats.map((chat) {
                  if (chat['friend_id'] == user['id']) {
                    return {
                      ...chat,
                      'friend_full_name':
                          user['full_name'] ?? chat['friend_full_name'],
                      'friend_avatar_url':
                          user['avatar_url'] ?? chat['friend_avatar_url'],
                      'friend_status': user['status'] ?? chat['friend_status'],
                    };
                  }
                  return chat;
                }).toList();

            await _dbService.saveChats(userId, updatedChats);
            onUpdate(updatedChats);
          },
        )
        .subscribe();
  }

  Future<List<Map<String, dynamic>>> loadMessages(
    String conversationId, {
    int limit = MESSAGE_PAGE_SIZE, // Sử dụng MESSAGE_PAGE_SIZE thay vì 20
    String? beforeSentAt,
  }) async {
    try {
      if (!(await _isOnline())) {
        final localMessages = await _dbService.loadMessages(
          conversationId,
          limit: limit,
          beforeSentAt: beforeSentAt,
        );
        print(
          'Offline: Returning ${localMessages.length} local messages for conversation $conversationId',
        );
        return localMessages;
      }

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

      final messages = await query
          .order('sent_at', ascending: false)
          .limit(limit);

      print(
        'Loaded ${messages.length} messages from Supabase for conversation $conversationId${beforeSentAt != null ? ' before $beforeSentAt' : ''}',
      );

      if (messages.isNotEmpty) {
        await _dbService.saveMessages(conversationId, messages);
        for (var message in messages) {
          if (message['users'] != null) {
            await _dbService.saveUser(message['users']);
          }
        }
      }

      return messages;
    } catch (e) {
      print('Error loading messages: $e');
      final localMessages = await _dbService.loadMessages(
        conversationId,
        limit: limit,
        beforeSentAt: beforeSentAt,
      );
      print(
        'Error/Offline: Returning ${localMessages.length} local messages for conversation $conversationId',
      );
      return localMessages;
    }
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

      await _dbService.saveMessages(conversationId, [messageResponse]);
      if (messageResponse['users'] != null) {
        await _dbService.saveUser(messageResponse['users']);
      }

      return messageResponse;
    } catch (e) {
      print('Error sending message: $e');
      throw Exception('Lỗi khi gửi tin nhắn: $e');
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

        final messages = await loadMessages(conversationId);
        await _dbService.saveMessages(conversationId, messages);
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

            await _dbService.saveMessages(conversationId, [message]);
            if (message['users'] != null) {
              await _dbService.saveUser(message['users']);
            }

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
      final chats = await loadChatsByUserId(userId);
      final updatedChats =
          chats.map((chat) {
            if (chat['conversation_id'] == conversationId) {
              return {...chat, 'is_read': true};
            }
            return chat;
          }).toList();
      await _dbService.saveChats(userId, updatedChats);
      print('Updated is_read for conversation $conversationId in SQLite');
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
}
