import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/utils/constants.dart';
import 'dart:io';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> _isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  Future<String> _uploadFile(
    File file,
    String messageType,
    String conversationId,
  ) async {
    try {
      final String bucket = switch (messageType) {
        'image' => 'pictures',
        'video' => 'videos',
        'file' => 'files',
        'audio' => 'audio',
        _ => throw Exception('Loại media không hợp lệ: $messageType'),
      };

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final filePath = '$conversationId/$fileName';

      await _supabase.storage.from(bucket).upload(filePath, file);

      final publicUrl = _supabase.storage.from(bucket).getPublicUrl(filePath);
      print('Uploaded $messageType to $bucket: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('Error uploading file: $e');
      throw Exception('Lỗi khi tải file lên: $e');
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String messageType = 'text',
    File? mediaFile,
  }) async {
    try {
      if (!(await _isOnline())) {
        throw Exception('Không có kết nối mạng');
      }

      String finalContent = content;
      if (mediaFile != null && messageType != 'text') {
        finalContent = await _uploadFile(
          mediaFile,
          messageType,
          conversationId,
        );
      }

      final messageResponse =
          await _supabase
              .from('messages')
              .insert({
                'conversation_id': conversationId,
                'sender_id': senderId,
                'content': finalContent,
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

      return messageResponse;
    } catch (e) {
      print('Error sending message: $e');
      throw Exception('Lỗi khi gửi tin nhắn: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadChatsByUserId(String userId) async {
    try {
      if (!(await _isOnline())) {
        print('Offline: Returning local chats for user $userId');
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
                .limit(1)
                .maybeSingle();

        if (friendResponse == null) {
          print('No friend found for conversation: $conversationId, skipping');
          continue;
        }

        final friend = friendResponse['users'] as Map<String, dynamic>?;
        if (friend == null || friend['id'] == null) {
          print(
            'Invalid friend data for conversation: $conversationId, skipping',
          );
          continue;
        }

        final lastMessage =
            await _supabase
                .from('messages')
                .select('id, content, sent_at, message_type')
                .eq('conversation_id', conversationId)
                .order('sent_at', ascending: false)
                .limit(1)
                .maybeSingle();

        bool isRead = true;
        String displayMessage = 'Chưa có tin nhắn';
        bool isHidden = false;
        DateTime? lastMessageTime;
        if (lastMessage != null) {
          final lastMessageStatus =
              await _supabase
                  .from('message_statuses')
                  .select('is_read, is_hidden')
                  .eq('message_id', lastMessage['id'])
                  .eq('user_id', userId)
                  .maybeSingle();
          isRead = lastMessageStatus?['is_read'] ?? true;
          isHidden = lastMessageStatus?['is_hidden'] ?? false;
          lastMessageTime = DateTime.parse(lastMessage['sent_at']).toLocal();

          if (isHidden) {
            displayMessage = 'Tin nhắn đã bị xóa';
          } else {
            final messageType = lastMessage['message_type'] as String;
            displayMessage = switch (messageType) {
              'image' => 'Hình ảnh',
              'video' => 'Video',
              'file' => 'File',
              'call' => 'Cuộc gọi',
              'audio' => 'Âm thanh',
              _ => lastMessage['content'] ?? 'Chưa có tin nhắn',
            };
          }

          print(
            'Last message for $conversationId: $displayMessage, sent_at: ${lastMessage['sent_at']}, is_read: $isRead, is_hidden: $isHidden',
          );
        } else {
          print('No messages for $conversationId, skipping');
          continue;
        }

        processedChats.add({
          'conversation_id': conversationId,
          'friend_id': friend['id'],
          'friend_full_name': friend['full_name'] as String? ?? 'Unknown',
          'friend_avatar_url': friend['avatar_url'] as String? ?? '',
          'friend_status': friend['status'] as String? ?? 'offline',
          'last_message': displayMessage,
          'last_message_time': lastMessageTime,
          'is_read': isRead,
          'is_group': chat['conversations']['is_group'],
        });
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

      print('Marked conversation $conversationId as deleted for user $userId');
    } catch (e) {
      print('Error marking conversation as deleted: $e');
      throw Exception('Lỗi khi xóa cuộc trò chuyện: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
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

      return response;
    } catch (e) {
      print('Error fetching user info: $e');
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
                      .select('id, content, sent_at, message_type')
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
                      .limit(1)
                      .maybeSingle();

              if (friendResponse == null) {
                print('No friend found for conversation: $conversationId');
                return;
              }

              final friend = friendResponse['users'] as Map<String, dynamic>?;
              if (friend == null || friend['id'] == null) {
                print('Invalid friend data for conversation: $conversationId');
                return;
              }

              final lastMessageStatus =
                  await _supabase
                      .from('message_statuses')
                      .select('is_read, is_hidden')
                      .eq('message_id', lastMessage['id'])
                      .eq('user_id', userId)
                      .maybeSingle();
              final isRead = lastMessageStatus?['is_read'] ?? true;
              final isHidden = lastMessageStatus?['is_hidden'] ?? false;

              String displayMessage = 'Chưa có tin nhắn';
              if (isHidden) {
                displayMessage = 'Tin nhắn đã bị xóa';
              } else {
                final messageType = lastMessage['message_type'] as String;
                displayMessage = switch (messageType) {
                  'image' => 'Hình ảnh',
                  'video' => 'Video',
                  'file' => 'File',
                  'call' => 'Cuộc gọi',
                  'audio' => 'Âm thanh',
                  _ => lastMessage['content'] ?? 'Chưa có tin nhắn',
                };
              }

              final updatedChat = {
                'conversation_id': conversationId,
                'friend_id': friend['id'],
                'friend_full_name': friend['full_name'] as String? ?? 'Unknown',
                'friend_avatar_url': friend['avatar_url'] as String? ?? '',
                'friend_status': friend['status'] as String? ?? 'offline',
                'last_message': displayMessage,
                'last_message_time':
                    DateTime.parse(lastMessage['sent_at']).toLocal(),
                'is_read': isRead,
                'is_group': false,
              };

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
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            try {
              final updatedStatus = payload.newRecord;
              final messageId = updatedStatus['message_id'] as String;

              final message =
                  await _supabase
                      .from('messages')
                      .select('conversation_id, content, sent_at, message_type')
                      .eq('id', messageId)
                      .single();

              final conversationId = message['conversation_id'] as String;

              final friendResponse =
                  await _supabase
                      .from('conversation_participants')
                      .select(
                        'user_id, users!inner(id, full_name, avatar_url, status)',
                      )
                      .eq('conversation_id', conversationId)
                      .neq('user_id', userId)
                      .eq('is_deleted', false)
                      .limit(1)
                      .maybeSingle();

              if (friendResponse == null) {
                print('No friend found for conversation: $conversationId');
                return;
              }

              final friend = friendResponse['users'] as Map<String, dynamic>?;
              if (friend == null || friend['id'] == null) {
                print('Invalid friend data for conversation: $conversationId');
                return;
              }

              final lastMessage =
                  await _supabase
                      .from('messages')
                      .select('id, content, sent_at, message_type')
                      .eq('conversation_id', conversationId)
                      .order('sent_at', ascending: false)
                      .limit(1)
                      .maybeSingle();

              if (lastMessage == null) {
                print('No last message found for conversation $conversationId');
                return;
              }

              final lastMessageStatus =
                  await _supabase
                      .from('message_statuses')
                      .select('is_read, is_hidden')
                      .eq('message_id', lastMessage['id'])
                      .eq('user_id', userId)
                      .maybeSingle();
              final isRead = lastMessageStatus?['is_read'] ?? true;
              final isHiddenStatus = lastMessageStatus?['is_hidden'] ?? false;

              String displayMessage = 'Chưa có tin nhắn';
              if (isHiddenStatus) {
                displayMessage = 'Tin nhắn đã bị xóa';
              } else {
                final messageType = lastMessage['message_type'] as String;
                displayMessage = switch (messageType) {
                  'image' => 'Hình ảnh',
                  'video' => 'Video',
                  'file' => 'File',
                  'call' => 'Cuộc gọi',
                  _ => lastMessage['content'] ?? 'Chưa có tin nhắn',
                };
              }

              final updatedChat = {
                'conversation_id': conversationId,
                'friend_id': friend['id'],
                'friend_full_name': friend['full_name'] as String? ?? 'Unknown',
                'friend_avatar_url': friend['avatar_url'] as String? ?? '',
                'friend_status': friend['status'] as String? ?? 'offline',
                'last_message': displayMessage,
                'last_message_time':
                    DateTime.parse(lastMessage['sent_at']).toLocal(),
                'is_read': isRead,
                'is_group': false,
              };

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

              final currentChats = await loadChatsByUserId(userId);
              final updatedChats =
                  currentChats.map((chat) {
                    if (chat['friend_id'] == user['id']) {
                      return {
                        ...chat,
                        'friend_full_name':
                            user['full_name'] as String? ??
                            chat['friend_full_name'] as String? ??
                            'Unknown',
                        'friend_avatar_url':
                            user['avatar_url'] as String? ??
                            chat['friend_avatar_url'] as String? ??
                            '',
                        'friend_status':
                            user['status'] as String? ??
                            chat['friend_status'] as String? ??
                            'offline',
                      };
                    }
                    return chat;
                  }).toList();

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

  Future<List<Map<String, dynamic>>> loadMessages(
    String conversationId, {
    int limit = MESSAGE_PAGE_SIZE,
    String? beforeSentAt,
  }) async {
    try {
      if (!(await _isOnline())) {
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
            message_statuses(user_id, is_read, read_at, is_hidden)
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

      for (var message in messages) {
        if (message['message_type'] == 'call') {
          final callId = message['content'];
          final callInfo =
              await _supabase
                  .from('call_requests')
                  .select('is_video_call, status, created_at, ended_at')
                  .eq('id', callId)
                  .maybeSingle();
          message['call_info'] = callInfo;
        }
      }

      print(
        'Loaded ${messages.length} messages from Supabase for conversation $conversationId${beforeSentAt != null ? ' before $beforeSentAt' : ''}',
      );

      return messages;
    } catch (e) {
      print('Error loading messages: $e');
      throw Exception('Lỗi khi tải tin nhắn: $e');
    }
  }

  Future<Map<String, dynamic>> loadMessagesAroundMessageId(
    String conversationId,
    String messageId, {
    int limit = 20,
  }) async {
    try {
      if (!(await _isOnline())) {
        throw Exception('Không có kết nối mạng');
      }

      // Lấy thông tin của tin nhắn với messageId để lấy sent_at
      final targetMessage =
          await _supabase
              .from('messages')
              .select('sent_at')
              .eq('id', messageId)
              .eq('conversation_id', conversationId)
              .single();

      if (targetMessage.isEmpty) {
        throw Exception('Không tìm thấy tin nhắn với ID: $messageId');
      }

      final targetSentAt = targetMessage['sent_at'];

      // Truy vấn các tin nhắn từ messageId trở đi
      final messagesFromTarget = await _supabase
          .from('messages')
          .select('''
          id, conversation_id, sender_id, content, sent_at, message_type,
          users!sender_id(id, full_name, avatar_url, status),
          message_statuses(user_id, is_read, read_at, is_hidden)
        ''')
          .eq('conversation_id', conversationId)
          .gte('sent_at', targetSentAt)
          .order('sent_at', ascending: true)
          .limit(limit);

      // Sắp xếp tin nhắn theo thứ tự giảm dần (mới nhất trước)
      final sortedMessages =
          messagesFromTarget..sort(
            (a, b) => DateTime.parse(
              b['sent_at'],
            ).compareTo(DateTime.parse(a['sent_at'])),
          );

      // Tìm index của messageId
      final targetIndex = sortedMessages.indexWhere(
        (msg) => msg['id'] == messageId,
      );

      // Xử lý thông tin cuộc gọi nếu có
      for (var message in sortedMessages) {
        if (message['message_type'] == 'call') {
          final callId = message['content'];
          final callInfo =
              await _supabase
                  .from('call_requests')
                  .select('is_video_call, status, created_at, ended_at')
                  .eq('id', callId)
                  .maybeSingle();
          message['call_info'] = callInfo;
        }
      }

      print(
        'Loaded ${sortedMessages.length} messages from messageId $messageId for conversation $conversationId, targetIndex: $targetIndex',
      );

      return {'messages': sortedMessages, 'targetIndex': targetIndex};
    } catch (e) {
      print('Error loading messages around messageId $messageId: $e');
      throw Exception('Lỗi khi tải tin nhắn: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadNewerMessages(
    String conversationId, {
    required String afterSentAt,
    int limit = MESSAGE_PAGE_SIZE,
  }) async {
    try {
      if (!(await _isOnline())) {
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
          message_statuses(user_id, is_read, read_at, is_hidden)
        ''')
          .eq('conversation_id', conversationId)
          .gt('sent_at', afterSentAt);

      if (participant != null && participant['deleted_at'] != null) {
        query = query.gt('sent_at', participant['deleted_at']);
      }

      final messages = await query
          .order('sent_at', ascending: true)
          .limit(limit);

      for (var message in messages) {
        if (message['message_type'] == 'call') {
          final callId = message['content'];
          final callInfo =
              await _supabase
                  .from('call_requests')
                  .select('is_video_call, status, created_at, ended_at')
                  .eq('id', callId)
                  .maybeSingle();
          message['call_info'] = callInfo;
        }
      }

      print(
        'Loaded ${messages.length} newer messages for conversation $conversationId after $afterSentAt',
      );

      return messages;
    } catch (e) {
      print('Error loading newer messages: $e');
      throw Exception('Lỗi khi tải tin nhắn mới hơn: $e');
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
                  message_statuses(user_id, is_read, read_at, is_hidden)
                ''')
                    .eq('id', newMessage['id'])
                    .single();

            if (message['message_type'] == 'call') {
              final callId = message['content'];
              final callInfo =
                  await _supabase
                      .from('call_requests')
                      .select('is_video_call, status, created_at, ended_at')
                      .eq('id', callId)
                      .maybeSingle();
              message['call_info'] = callInfo;
            }
            onUpdate([message]);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'message_statuses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _supabase.auth.currentUser!.id,
          ),
          callback: (payload) async {
            try {
              final updatedStatus = payload.newRecord;
              final messageId = updatedStatus['message_id'] as String;

              final message =
                  await _supabase
                      .from('messages')
                      .select('''
                      id, conversation_id, sender_id, content, sent_at, message_type,
                      users!sender_id(id, full_name, avatar_url, status),
                      message_statuses(user_id, is_read, read_at, is_hidden)
                    ''')
                      .eq('id', messageId)
                      .eq('conversation_id', conversationId)
                      .single();

              if (message['message_type'] == 'call') {
                final callId = message['content'];
                final callInfo =
                    await _supabase
                        .from('call_requests')
                        .select('is_video_call, status, created_at, ended_at')
                        .eq('id', callId)
                        .maybeSingle();
                message['call_info'] = callInfo;
              }
              onUpdate([message]);
            } catch (e) {
              print('Error processing message_statuses update event: $e');
            }
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

  Future<List<Map<String, dynamic>>> findMessages(String search) async {
    try {
      return await _supabase.rpc(
        "find_messages",
        params: {
          "search": search,
          "user_query": _supabase.auth.currentUser!.id,
        },
      );
    } catch (e) {
      print(e);
      return [];
    }
  }

  Future<void> deleteMessageForMe(String messageId, String userId) async {
    try {
      if (!(await _isOnline())) {
        throw Exception('Không có kết nối mạng');
      }

      await _supabase
          .from('message_statuses')
          .update({'is_hidden': true})
          .eq('message_id', messageId)
          .eq('user_id', userId);
      print('Deleted message $messageId for user $userId');
    } catch (e) {
      print('Error deleting message for user: $e');
      throw Exception('Lỗi khi xóa tin nhắn: $e');
    }
  }

  Future<void> deleteMessageForAll(String messageId) async {
    try {
      if (!(await _isOnline())) {
        throw Exception('Không có kết nối mạng');
      }

      await _supabase
          .from('message_statuses')
          .update({'is_hidden': true})
          .eq('message_id', messageId);
      print('Deleted message $messageId for all users');
    } catch (e) {
      print('Error deleting message for all: $e');
      throw Exception('Lỗi khi xóa tin nhắn: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getListFiles(
    String conversationId,
    int amount,
    int page,
  ) async {
    try {
      return _supabase.rpc(
        "list_files",
        params: {
          'conversation': conversationId,
          'user_query': _supabase.auth.currentUser!.id,
          'amount': amount,
          'page': page,
        },
      );
    } catch (e) {
      print(e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getListImages(
    String conversationId,
    int amount,
    int page,
  ) async {
    try {
      return _supabase.rpc(
        "list_images",
        params: {
          'conversation': conversationId,
          'user_query': _supabase.auth.currentUser!.id,
          'amount': amount,
          'page': page,
        },
      );
    } catch (e) {
      print(e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getListVideos(
    String conversationId,
    int amount,
    int page,
  ) async {
    try {
      return _supabase.rpc(
        "list_videos",
        params: {
          'conversation': conversationId,
          'user_query': _supabase.auth.currentUser!.id,
          'amount': amount,
          'page': page,
        },
      );
    } catch (e) {
      print(e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getListAudio(
    String conversationId,
    int amount,
    int page,
  ) async {
    try {
      return _supabase.rpc(
        "list_audio",
        params: {
          'conversation': conversationId,
          'user_query': _supabase.auth.currentUser!.id,
          'amount': amount,
          'page': page,
        },
      );
    } catch (e) {
      print(e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getListMultimedia(
    String conversationId,
    int amount,
    int page,
  ) async {
    try {
      return _supabase.rpc(
        "list_multimedia",
        params: {
          'conversation': conversationId,
          'user_query': _supabase.auth.currentUser!.id,
          'amount': amount,
          'page': page,
        },
      );
    } catch (e) {
      print(e);
      return [];
    }
  }
}
