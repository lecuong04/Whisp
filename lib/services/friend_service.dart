import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/models/friend.dart';
import 'package:whisp/models/tag.dart';

class FriendService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Friend>> listFriends() async {
    var data = await _supabase.rpc(
      "list_friends",
      params: {"_user_id": _supabase.auth.currentUser?.id},
    );
    List<Friend> output = List.empty(growable: true);
    for (dynamic f in data) {
      List<String> tags = List.empty(growable: true);
      for (dynamic d in f["tags"]) {
        tags.add(d.toString());
      }
      output.add(
        Friend(
          f["id"],
          f["username"],
          f["full_name"],
          f["avatar_url"] ?? "",
          f["status"],
          tags,
        ),
      );
    }
    return output;
  }

  Future<List<Tag>> listTags() async {
    var data = await _supabase.rpc(
      "list_tags",
      params: {"_user_id": _supabase.auth.currentUser?.id},
    );
    List<Tag> output = List.empty(growable: true);
    for (dynamic f in data) {
      output.add(Tag.json(f));
    }
    return output;
  }
}
