import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:whisp/utils/constants.dart'; // Import constants.dart

class DatabaseService {
  static Database? _database;
  static const _databaseName = 'whisp.db';
  static const _databaseVersion = 1;

  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT,
        sender_id TEXT,
        content TEXT,
        sent_at TEXT,
        message_type TEXT,
        sender_info TEXT,
        statuses TEXT,
        UNIQUE(conversation_id, id)
      )
    ''');
    await db.execute('''
      CREATE TABLE chats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id TEXT,
        user_id TEXT,
        friend_id TEXT,
        friend_full_name TEXT,
        friend_avatar_url TEXT,
        friend_status TEXT,
        last_message TEXT,
        last_message_time TEXT,
        is_read INTEGER,
        is_group INTEGER,
        UNIQUE(conversation_id, user_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        full_name TEXT,
        avatar_url TEXT,
        status TEXT
      )
    ''');
    print('Created tables: messages, chats, users');
  }

  Future<void> saveMessages(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async {
    final db = await database;
    final batch = db.batch();

    for (var message in messages) {
      batch.insert('messages', {
        'id': message['id'],
        'conversation_id': message['conversation_id'],
        'sender_id': message['sender_id'],
        'content': message['content'],
        'sent_at': message['sent_at'],
        'message_type': message['message_type'],
        'sender_info': jsonEncode(message['users']),
        'statuses': jsonEncode(message['message_statuses']),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit();
    print('Saved ${messages.length} messages for conversation $conversationId');

    await _trimMessages(conversationId);
  }

  Future<void> _trimMessages(String conversationId) async {
    final db = await database;
    const limit = MESSAGE_PAGE_SIZE; // Sử dụng MESSAGE_PAGE_SIZE thay vì 20

    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE conversation_id = ?',
      [conversationId],
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;

    if (count > limit) {
      await db.rawDelete(
        '''
        DELETE FROM messages
        WHERE conversation_id = ? AND id IN (
          SELECT id FROM messages
          WHERE conversation_id = ?
          ORDER BY sent_at DESC
          LIMIT -1 OFFSET ?
        )
        ''',
        [conversationId, conversationId, limit],
      );
      print('Trimmed messages for conversation $conversationId to $limit');
    }
  }

  Future<List<Map<String, dynamic>>> loadMessages(
    String conversationId, {
    int limit = MESSAGE_PAGE_SIZE, // Sử dụng MESSAGE_PAGE_SIZE thay vì 20
    String? beforeSentAt,
  }) async {
    final db = await database;
    String whereClause = 'conversation_id = ?';
    List<dynamic> whereArgs = [conversationId];

    if (beforeSentAt != null) {
      whereClause += ' AND sent_at < ?';
      whereArgs.add(beforeSentAt);
    }

    final result = await db.query(
      'messages',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'sent_at DESC',
      limit: limit,
    );

    final messages =
        result.map((row) {
          return {
            'id': row['id'],
            'conversation_id': row['conversation_id'],
            'sender_id': row['sender_id'],
            'content': row['content'],
            'sent_at': row['sent_at'],
            'message_type': row['message_type'],
            'users': jsonDecode(row['sender_info'] as String),
            'message_statuses': jsonDecode(row['statuses'] as String),
          };
        }).toList();

    print(
      'Loaded ${messages.length} messages from SQLite for conversation $conversationId${beforeSentAt != null ? ' before $beforeSentAt' : ''}',
    );
    return messages;
  }

  Future<void> deleteMessages(String conversationId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
    print('Deleted messages for conversation $conversationId');
  }

  Future<void> saveChats(
    String userId,
    List<Map<String, dynamic>> chats,
  ) async {
    final db = await database;
    final batch = db.batch();

    for (var chat in chats) {
      batch.insert('chats', {
        'conversation_id': chat['conversation_id'],
        'user_id': userId,
        'friend_id': chat['friend_id'],
        'friend_full_name': chat['friend_full_name'],
        'friend_avatar_url': chat['friend_avatar_url'],
        'friend_status': chat['friend_status'],
        'last_message': chat['last_message'],
        'last_message_time': chat['last_message_time'].toIso8601String(),
        'is_read': chat['is_read'] ? 1 : 0,
        'is_group': chat['is_group'] ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit();
    print('Saved ${chats.length} chats for user $userId');
  }

  Future<List<Map<String, dynamic>>> loadChats(String userId) async {
    final db = await database;
    final result = await db.query(
      'chats',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'last_message_time DESC',
    );

    final chats =
        result.map((row) {
          return {
            'conversation_id': row['conversation_id'],
            'friend_id': row['friend_id'],
            'friend_full_name': row['friend_full_name'],
            'friend_avatar_url': row['friend_avatar_url'],
            'friend_status': row['friend_status'],
            'last_message': row['last_message'],
            'last_message_time': DateTime.parse(
              row['last_message_time'] as String,
            ),
            'is_read': (row['is_read'] as int) == 1,
            'is_group': (row['is_group'] as int) == 1,
          };
        }).toList();

    print('Loaded ${chats.length} chats from SQLite for user $userId');
    return chats;
  }

  Future<void> deleteChats(String userId) async {
    final db = await database;
    await db.delete('chats', where: 'user_id = ?', whereArgs: [userId]);
    print('Deleted chats for user $userId');
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final db = await database;
    await db.insert('users', {
      'id': user['id'],
      'full_name': user['full_name'],
      'avatar_url': user['avatar_url'],
      'status': user['status'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    print('Saved user ${user['id']} to SQLite');
  }

  Future<Map<String, dynamic>?> loadUser(String userId) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (result.isEmpty) {
      print('No user found in SQLite for userId $userId');
      return null;
    }

    final row = result.first;
    final user = {
      'id': row['id'],
      'full_name': row['full_name'],
      'avatar_url': row['avatar_url'],
      'status': row['status'],
    };
    print('Loaded user ${user['id']} from SQLite');
    return user;
  }

  Future<void> deleteUser(String userId) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
    print('Deleted user $userId from SQLite');
  }
}
