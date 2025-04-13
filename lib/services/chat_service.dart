import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Load 20 tin nhắn gần nhất
  Stream<List<Map<String, dynamic>>> getMessagesStream(String chatId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('timestamp', ascending: true)
        .limit(20)
        .map(
          (data) => data.map((item) => item as Map<String, dynamic>).toList(),
        );
  }

  // Load thêm tin nhắn cũ
  Future<List<Map<String, dynamic>>> loadMoreMessages(
    String chatId,
    Map<String, dynamic> firstMessage,
  ) async {
    final response = await _supabase
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .lt('timestamp', firstMessage['timestamp'])
        .order('timestamp', ascending: false)
        .limit(20);

    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  // Gửi tin nhắn dạng text
  Future<Map<String, dynamic>> sendMessage(
    String chatId,
    String senderId,
    String receiverId,
    String text,
  ) async {
    final messageData = {
      'chat_id': chatId,
      'sender_id': senderId,
      'text': text,
      'received': {senderId: true, receiverId: false},
      'timestamp': DateTime.now().toIso8601String(),
    };

    final response =
        await _supabase.from('messages').insert(messageData).select().single();

    await _supabase
        .from('chats')
        .update({
          'last_message': text,
          'last_message_time': DateTime.now().toIso8601String(),
        })
        .eq('id', chatId);

    return response as Map<String, dynamic>;
  }

  // Cập nhật trạng thái isReceived khi người dùng xem tin nhắn
  Future<void> markMessagesAsReceived(String chatId, String userId) async {
    final messages = await _supabase
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .eq('received->$userId', false);

    for (var message in messages) {
      await _supabase
          .from('messages')
          .update({
            'received': {...message['received'], userId: true},
          })
          .eq('id', message['id']);
    }
  }

  // Kiểm tra xem đoạn chat có tin nhắn chưa xem không
  Future<bool> hasUnreadMessages(String chatId, String userId) async {
    final response = await _supabase
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .eq('received->$userId', false);

    return response.isNotEmpty;
  }

  // Load danh sách đoạn chat theo userId
  Future<List<Map<String, dynamic>>> loadChatsByUserId(String userId) async {
    try {
      print("id trong loadchats: $userId");
      final response = await _supabase
          .from('chats')
          .select()
          .withConverter(
            (data) =>
                data.where((row) {
                  final participants =
                      (row['participants'] as List<dynamic>).cast<String>();
                  return participants.contains(userId);
                }).toList(),
          );

      print("Danh sách đoạn chat trả về: $response");
      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      print("Lỗi khi tải danh sách đoạn chat: $e");
      return [];
    }
  }

  // Hàm debug: Lấy tất cả dữ liệu trong bảng chats để kiểm tra
  Future<List<Map<String, dynamic>>> debugGetAllChats() async {
    try {
      final response = await _supabase.from('chats').select();
      print("Tất cả dữ liệu trong bảng chats: $response");
      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      print("Lỗi khi lấy tất cả dữ liệu bảng chats: $e");
      return [];
    }
  }
}
