import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/models/friend_request.dart';

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get id {
    return _supabase.auth.currentUser?.id;
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      return await _supabase
          .rpc('get_user', params: {'user_id': userId})
          .single();
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<List<FriendRequest>> findUsers(String username) async {
    if (username.length < 2) return List.empty();
    List<FriendRequest> result = List.empty(growable: true);
    try {
      var data = await _supabase.rpc(
        "find_users",
        params: {"search": username, "user_id": _supabase.auth.currentUser?.id},
      );
      for (var item in data) {
        result.add(FriendRequest.map(item));
      }
    } catch (e) {
      print(e);
    }
    return result;
  }

  Future<List<FriendRequest>> listFriendRequest() async {
    List<FriendRequest> result = List.empty(growable: true);
    try {
      var data = await _supabase.rpc(
        "list_friend_request",
        params: {"user_id": _supabase.auth.currentUser?.id},
      );
      for (var item in data) {
        result.add(FriendRequest.map(item));
      }
    } catch (e) {
      print(e);
    }
    ;
    return result;
  }

  Future<String> getIdFromUsername(String username) async {
    try {
      var data = await _supabase.rpc(
        "get_id_from_username",
        params: {
          "_username": username,
          "user_query": _supabase.auth.currentUser?.id,
        },
      );
      return data ??= "";
    } catch (e) {
      print(e);
      return "";
    }
  }

  Future blockUser(String username) async {
    try {
      await _supabase.rpc(
        "block_user",
        params: {
          "_username": username,
          "user_query": _supabase.auth.currentUser?.id,
        },
      );
    } catch (e) {
      print(e);
    }
  }
}
