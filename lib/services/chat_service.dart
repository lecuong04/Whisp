import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Tải danh sách cuộc trò chuyện 1-1 của người dùng
  Future<List<Map<String, dynamic>>> loadChatsByUserId(String userId) async {
    try {
      // Lấy danh sách cuộc trò chuyện của người dùng
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
      print('User chats: $userChats');

      final processedChats = <Map<String, dynamic>>[];
      for (var chat in userChats) {
        final conversationId = chat['conversation_id'];
        print('Processing conversation: $conversationId');

        // Lấy thông tin người bạn
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

        // Lấy tin nhắn mới nhất
        final lastMessage =
            await _supabase
                .from('messages')
                .select('id, content, sent_at')
                .eq('conversation_id', conversationId)
                .order('sent_at', ascending: false)
                .limit(1)
                .maybeSingle();

        // Lấy trạng thái is_read của tin nhắn mới nhất
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

        // Chuyển sent_at thành giờ địa phương
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
            'last_message': lastMessage?['content'] ?? 'Chưa có tin nhắn',
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
      return processedChats;
    } catch (e) {
      print('Error loading chats: $e');
      throw Exception('Lỗi khi tải danh sách chat: $e');
    }
  }

  /// Tạo hoặc lấy cuộc trò chuyện 1-1 với một người dùng khác
  Future<String> createDirectConversation(
    String currentUserId,
    String otherUserId,
  ) async {
    try {
      final existingConversation =
          await _supabase
              .from('conversation_participants')
              .select('conversation_id, conversations!inner(is_group)')
              .eq('user_id', currentUserId)
              .inFilter(
                'conversation_id',
                await _supabase
                    .from('conversation_participants')
                    .select('conversation_id')
                    .eq('user_id', otherUserId),
              )
              .eq('conversations.is_group', false)
              .maybeSingle();

      if (existingConversation != null) {
        return existingConversation['conversation_id'] as String;
      }

      final conversation =
          await _supabase
              .from('conversations')
              .insert({'created_by': currentUserId, 'is_group': false})
              .select('id')
              .single();

      final conversationId = conversation['id'] as String;

      await _supabase.from('conversation_participants').insert([
        {'conversation_id': conversationId, 'user_id': currentUserId},
        {'conversation_id': conversationId, 'user_id': otherUserId},
      ]);

      return conversationId;
    } catch (e) {
      throw Exception('Lỗi khi tạo cuộc trò chuyện: $e');
    }
  }

  /// Lấy thông tin người dùng theo ID
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final response =
          await _supabase
              .from('users')
              .select(
                'id, full_name, avatar_url, status',
              ) // Thay username thành full_name
              .eq('id', userId)
              .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Lỗi khi lấy thông tin người dùng: $e');
    }
  }

  /// Theo dõi thay đổi Realtime cho danh sách cuộc trò chuyện
  void subscribeToChats(
    String userId,
    Function(List<Map<String, dynamic>>) onUpdate,
  ) {
    final channel = _supabase.channel('public:chats');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) async {
            print('Realtime: Conversations changed - $payload');
            final updatedChats = await loadChatsByUserId(userId);
            onUpdate(updatedChats);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            print('Realtime: Messages changed - $payload');
            final updatedChats = await loadChatsByUserId(userId);
            onUpdate(updatedChats);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_statuses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            print('Realtime: Message statuses changed - $payload');
            final updatedChats = await loadChatsByUserId(userId);
            onUpdate(updatedChats);
          },
        )
        .subscribe((status, [error]) {
          print('Realtime channel status: $status, error: $error');
        });
  }

  /// Tải danh sách tin nhắn trong một cuộc trò chuyện
  Future<List<Map<String, dynamic>>> loadMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('''
            id,
            conversation_id,
            sender_id,
            content,
            sent_at,
            is_edited,
            edited_at,
            message_type,
            users!sender_id(id, full_name, avatar_url) // Thay username thành full_name
          ''')
          .eq('conversation_id', conversationId)
          .eq('message_type', 'text')
          .order('sent_at', ascending: true)
          .limit(limit);

      return response;
    } catch (e) {
      throw Exception('Lỗi khi tải tin nhắn: $e');
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    try {
      final response =
          await _supabase
              .from('messages')
              .insert({
                'conversation_id': conversationId,
                'sender_id': senderId,
                'content': content,
                'message_type': 'text',
              })
              .select('''
            id,
            conversation_id,
            sender_id,
            content,
            sent_at,
            is_edited,
            edited_at,
            message_type,
            users!sender_id(id, full_name, avatar_url) // Thay username thành full_name
          ''')
              .single();

      // Kiểm tra message_statuses (để debug)
      final statusCheck = await _supabase
          .from('message_statuses')
          .select('user_id, is_read')
          .eq('message_id', response['id']);
      print(
        'Message statuses created for message ${response['id']}: $statusCheck',
      );

      return response;
    } catch (e) {
      print('Error sending message: $e');
      throw Exception('Lỗi khi gửi tin nhắn: $e');
    }
  }

  /// Đánh dấu tin nhắn là đã đọc
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      final messageResponse = await _supabase
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId);

      final messageIds =
          messageResponse.map((msg) => msg['id'] as String).toList();
      print('Message IDs for conversation $conversationId: $messageIds');

      if (messageIds.isEmpty) {
        print('No messages found for conversation $conversationId');
        return;
      }

      final beforeUpdate = await _supabase
          .from('message_statuses')
          .select('id, message_id, is_read')
          .eq('user_id', _supabase.auth.currentUser!.id)
          .eq('is_read', false)
          .inFilter('message_id', messageIds);
      print('Messages to mark as read (before): $beforeUpdate');

      await _supabase
          .from('message_statuses')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .match({'user_id': _supabase.auth.currentUser!.id, 'is_read': false})
          .inFilter('message_id', messageIds);

      final afterUpdate = await _supabase
          .from('message_statuses')
          .select('id, message_id, is_read')
          .eq('user_id', _supabase.auth.currentUser!.id)
          .inFilter('message_id', messageIds);
      print('Messages after marking as read: $afterUpdate');
    } catch (e) {
      print('Error marking messages as read: $e');
      throw Exception('Lỗi khi đánh dấu đã đọc: $e');
    }
  }

  /// Theo dõi tin nhắn mới qua Realtime
  void subscribeToMessages(
    String conversationId,
    Function(List<Map<String, dynamic>>) onUpdate,
  ) {
    _supabase
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            final updatedMessages = await loadMessages(conversationId);
            onUpdate(updatedMessages);
          },
        )
        .subscribe();
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
