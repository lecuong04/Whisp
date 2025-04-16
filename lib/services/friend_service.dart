import 'package:supabase_flutter/supabase_flutter.dart';

class FriendService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> findUsers(String username) async {
    if (username.length < 2) return List.empty();
    var data = await _supabase.rpc(
      "find_users",
      params: {"search": username, "user_id": _supabase.auth.currentUser?.id},
    );
    List<Map<String, dynamic>> result = List.empty(growable: true);
    for (var item in data) {
      print(item);
      result.add(item);
    }
    return result;
  }
}
