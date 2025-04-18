import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/models/friend.dart';

class FriendService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Friend>> listFriends() async {
    var data = await _supabase.rpc(
      "list_friends",
      params: {"user_id": _supabase.auth.currentUser?.id},
    );
    List<Friend> output = List.empty(growable: true);
    for (dynamic f in data) {
      output.add(
        Friend(
          f["id"],
          f["username"],
          f["full_name"],
          f["avatar_url"] ?? "",
          f["status"],
        ),
      );
    }
    return output;
  }
}
