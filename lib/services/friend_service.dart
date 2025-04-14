import 'package:supabase_flutter/supabase_flutter.dart';

class FriendService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<dynamic>> findUsers(String username) async {
    if (username.length < 3) return List.empty();
    var data = await _supabase.rpc(
      "find_users",
      params: {
        "search": username,
        "user_query": _supabase.auth.currentUser?.id,
      },
    );
    print(data);
    return data;
  }
}
