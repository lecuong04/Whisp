import 'dart:ui';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/models/tag.dart';

class TagService {
  final SupabaseClient _supabase = Supabase.instance.client;

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

  Future<Tag?> addTag(String name, Color color) async {
    try {
      var data = await _supabase.rpc(
        "add_tag",
        params: {
          "user_id": _supabase.auth.currentUser?.id,
          "name": name,
          "color": color.toARGB32(),
        },
      );
      return Tag(data.toString(), name, color);
    } catch (e) {
      return null;
    }
  }

  Future<bool> removeTag(String tagId) async {
    var data = await _supabase.rpc(
      "remove_tag",
      params: {"_user_id": _supabase.auth.currentUser?.id, "tag_id": tagId},
    );
    return data;
  }

  Future<bool> addTagToFriend(String friendId, String tagId) async {
    var data = await _supabase.rpc(
      "add_tag_to_friend",
      params: {
        "_user_id": _supabase.auth.currentUser?.id,
        "friend_id": friendId,
        "tag_id": tagId,
      },
    );
    return data;
  }
}
