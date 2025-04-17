import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/models/friend.dart';

class FriendService {
  Future<List<Friend>> listFriends() async {
    final SupabaseClient supabase = Supabase.instance.client;
    var data = await supabase.rpc(
      "list_friends",
      params: {"user_id": supabase.auth.currentUser?.id},
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
