import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Tải danh sách cuộc trò chuyện 1-1 của người dùng
  Future<List<Map<String, dynamic>>> loadChatsByUserId(String userId) async {
    try {
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

        final friendResponse =
            await _supabase
                .from('conversation_participants')
                .select(
                  'user_id, users!inner(id, username, avatar_url, status)',
                )
                .eq('conversation_id', conversationId)
                .neq('user_id', userId)
                .maybeSingle();

        if (friendResponse == null) {
          continue;
        }

        final friend = friendResponse['users'] as Map<String, dynamic>;

        final lastMessage =
            await _supabase
                .from('messages')
                .select('id, content, sent_at')
                .eq('conversation_id', conversationId)
                .order('sent_at', ascending: false)
                .limit(1)
                .maybeSingle();

        final messageIds = await _supabase
            .from('messages')
            .select('id')
            .eq('conversation_id', conversationId);
        final unreadCount =
            messageIds.isEmpty
                ? 0
                : await _supabase
                    .from('message_statuses')
                    .select('id')
                    .eq('user_id', userId)
                    .eq('is_read', false)
                    .inFilter(
                      'message_id',
                      messageIds.map((m) => m['id']).toList(),
                    )
                    .count();

        processedChats.add({
          'conversation_id': conversationId,
          'friend_id': friend['id'],
          'friend_username': friend['username'] ?? 'Unknown',
          'friend_avatar_url':
              friend['avatar_url'] ?? 'https://via.placeholder.com/150',
          'friend_status': friend['status'] ?? 'offline',
          'last_message': lastMessage?['content'] ?? 'Chưa có tin nhắn',
          'last_message_time':
              lastMessage != null
                  ? DateTime.parse(lastMessage['sent_at'])
                  : DateTime.now(),
          'is_read': unreadCount == 0,
          'is_group': chat['conversations']['is_group'],
        });
      }

      processedChats.sort(
        (a, b) => b['last_message_time'].compareTo(a['last_message_time']),
      );
      return processedChats;
    } catch (e) {
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
              .select('id, username, avatar_url, status')
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
    _supabase
        .channel('public:conversations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) async {
            final updatedChats = await loadChatsByUserId(userId);
            onUpdate(updatedChats);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final updatedChats = await loadChatsByUserId(userId);
            onUpdate(updatedChats);
          },
        )
        .subscribe();
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
            users!sender_id(id, username, avatar_url)
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

  /// Gửi tin nhắn văn bản
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
            users!sender_id(id, username, avatar_url)
          ''')
              .single();

      return response;
    } catch (e) {
      throw Exception('Lỗi khi gửi tin nhắn: $e');
    }
  }

  /// Đánh dấu tin nhắn là đã đọc
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      // Lấy danh sách message_id
      final messageResponse = await _supabase
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId);

      // Trích xuất danh sách UUID
      final messageIds =
          messageResponse.map((msg) => msg['id'] as String).toList();

      // Nếu không có tin nhắn, bỏ qua
      if (messageIds.isEmpty) {
        return;
      }

      // Cập nhật trạng thái đã đọc
      await _supabase
          .from('message_statuses')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .match({'user_id': _supabase.auth.currentUser!.id, 'is_read': false})
          .inFilter('message_id', messageIds);
    } catch (e) {
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
}
