import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/models/friend_request.dart';

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? getMyId() {
    return _supabase.auth.currentUser?.id;
  }

  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final response =
          await _supabase
              .rpc('get_user_info', params: {'p_user_id': userId})
              .single();

      return {
        'username': response['username'] as String? ?? userId,
        'avatar_url':
            response['avatar_url'] as String? ??
            'https://via.placeholder.com/150',
      };
    } catch (e) {
      print('Error fetching user info via RPC: $e');
      return null;
    }
  }

  Future<List<FriendRequest>> findUsers(String username) async {
    if (username.length < 2) return List.empty();
    var data = await _supabase.rpc(
      "find_users",
      params: {"search": username, "user_id": _supabase.auth.currentUser?.id},
    );
    List<FriendRequest> result = List.empty(growable: true);
    for (var item in data) {
      result.add(FriendRequest.json(item));
    }
    return result;
  }

  Future<List<FriendRequest>> listFriendRequest() async {
    var data = await _supabase.rpc(
      "list_friend_request",
      params: {"user_id": _supabase.auth.currentUser?.id},
    );
    List<FriendRequest> result = List.empty(growable: true);
    for (var item in data) {
      result.add(FriendRequest.json(item));
    }
    return result;
  }

  Future<String> getIdFromUsername(String username) async {
    var data = await _supabase.rpc(
      "get_id_from_username",
      params: {
        "_username": username,
        "user_query": _supabase.auth.currentUser?.id,
      },
    );
    return data ??= "";
  }
}
