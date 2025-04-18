import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/services/db_service.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService.instance;

  /// Tải danh sách cuộc trò chuyện 1-1 của người dùng
  Future<List<Map<String, dynamic>>> loadChatsByUserId(String userId) async {
    try {
      // Ưu tiên tải từ SQLite
      final localChats = await _dbService.loadChats(userId);
      if (localChats.isNotEmpty) {
        return localChats;
      }

      // Nếu SQLite trống, truy vấn Supabase
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
      print('User chats from Supabase: $userChats');

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
        await _dbService.saveUser(friend); // Lưu thông tin bạn bè

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
        }

        final lastMessageTime =
            lastMessage != null
                ? DateTime.parse(lastMessage['sent_at']).toLocal()
                : DateTime.now().toLocal();
        if (lastMessage != null) {
          processedChats.add({
            'conversation_id': conversationId,
            'friend_id': friend['id'],
            'friend_full_name': friend['full_name'] ?? 'Unknown',
            'friend_avatar_url':
                friend['avatar_url'] ?? 'https://via.placeholder.com/150',
            'friend_status': friend['status'] ?? 'offline',
            'last_message': lastMessage['content'] ?? 'Chưa có tin nhắn',
            'last_message_time': lastMessageTime,
            'is_read': isRead,
            'is_group': chat['conversations']['is_group'],
          });
        }
      }

      processedChats.sort(
        (a, b) => b['last_message_time'].compareTo(a['last_message_time']),
      );
      print('Processed chats: $processedChats');

      // Lưu vào SQLite
      if (processedChats.isNotEmpty) {
        await _dbService.saveChats(userId, processedChats);
      }

      return processedChats;
    } catch (e) {
      print('Error loading chats: $e');
      throw Exception('Lỗi khi tải danh sách chat: $e');
    }
  }

  /// Tạo một cuộc trò chuyện trực tiếp
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

      // Cập nhật SQLite
      final chats = await loadChatsByUserId(userId1);
      await _dbService.saveChats(userId1, chats);

      return {'conversation_id': conversationId};
    } catch (e) {
      print('Error creating conversation: $e');
      throw Exception('Lỗi khi tạo cuộc trò chuyện: $e');
    }
  }

  /// Lấy thông tin người dùng
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      // Ưu tiên tải từ SQLite
      final localUser = await _dbService.loadUser(userId);
      if (localUser != null) {
        return localUser;
      }

      // Nếu không có trong SQLite, truy vấn Supabase
      final response =
          await _supabase
              .from('users')
              .select('id, full_name, avatar_url, status')
              .eq('id', userId)
              .maybeSingle();

      if (response != null) {
        await _dbService.saveUser(response); // Lưu vào SQLite
      }

      return response;
    } catch (e) {
      print('Error fetching user info: $e');
      // Nếu có lỗi (ví dụ: offline), thử tải lại từ SQLite
      final localUser = await _dbService.loadUser(userId);
      if (localUser != null) {
        return localUser;
      }
      throw Exception('Lỗi khi lấy thông tin người dùng: $e');
    }
  }

  /// Theo dõi các thay đổi trong danh sách cuộc trò chuyện
  void subscribeToChats(
    String userId,
    Function(List<Map<String, dynamic>>) onUpdate,
  ) {
    final channel = _supabase.channel('public:chats');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            print('Realtime payload for messages: $payload');
            final chats = await loadChatsByUserId(userId);
            await _dbService.saveChats(userId, chats); // Cập nhật SQLite
            onUpdate(chats);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_statuses',
          callback: (payload) async {
            print('Realtime payload for message_statuses: $payload');
            final chats = await loadChatsByUserId(userId);
            await _dbService.saveChats(userId, chats); // Cập nhật SQLite
            onUpdate(chats);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (payload) async {
            print('Realtime payload for users: $payload');
            final user = payload.newRecord;
            await _dbService.saveUser(user); // Cập nhật thông tin người dùng
            final chats = await loadChatsByUserId(userId);
            await _dbService.saveChats(
              userId,
              chats,
            ); // Cập nhật danh sách chat
            onUpdate(chats);
          },
        )
        .subscribe();
  }

  /// Tải danh sách tin nhắn của một cuộc trò chuyện với phân trang
  Future<List<Map<String, dynamic>>> loadMessages(
    String conversationId, {
    int limit = 20,
    String? beforeSentAt,
  }) async {
    try {
      // Ưu tiên tải từ SQLite
      if (beforeSentAt == null) {
        final localMessages = await _dbService.loadMessages(
          conversationId,
          limit: limit,
        );
        if (localMessages.length >= limit) {
          return localMessages;
        }
      }

      // Nếu không có đủ dữ liệu cục bộ, truy vấn Supabase
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
        'Loaded ${messages.length} messages from Supabase for conversation $conversationId',
      );

      // Lưu vào SQLite
      if (messages.isNotEmpty) {
        await _dbService.saveMessages(conversationId, messages);
        // Lưu thông tin người dùng từ messages
        for (var message in messages) {
          if (message['users'] != null) {
            await _dbService.saveUser(message['users']);
          }
        }
      }

      return messages;
    } catch (e) {
      print('Error loading messages: $e');
      throw Exception('Lỗi khi tải tin nhắn: $e');
    }
  }

  /// Gửi một tin nhắn
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      // Chèn tin nhắn mới
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

      // Lưu vào SQLite
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

  /// Đánh dấu tin nhắn là đã đọc
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
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

        // Cập nhật SQLite
        final messages = await loadMessages(conversationId);
        await _dbService.saveMessages(conversationId, messages);
      }
    } catch (e) {
      print('Error marking messages as read: $e');
      throw Exception('Lỗi khi đánh dấu tin nhắn đã đọc: $e');
    }
  }

  /// Theo dõi các tin nhắn mới trong một cuộc trò chuyện
  void subscribeToMessages(
    String conversationId,
    Function(List<Map<String, dynamic>>) onUpdate,
  ) {
    final channel = _supabase.channel('public:messages');

    channel
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
            print('Realtime message payload: $payload');
            final newMessage = payload.newRecord;
            // Tải thông tin bổ sung
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

            // Lưu vào SQLite
            await _dbService.saveMessages(conversationId, [message]);
            if (message['users'] != null) {
              await _dbService.saveUser(message['users']);
            }

            onUpdate([message]);
          },
        )
        .subscribe();
  }

  /// Cập nhật trạng thái đã đọc cho một đoạn chat
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
