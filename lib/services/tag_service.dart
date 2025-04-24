import 'dart:ui';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/models/tag.dart';

class TagService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Tag>> listTags() async {
    List<Tag> output = List.empty(growable: true);
    try {
      var data = await _supabase.rpc(
        "list_tags",
        params: {"_user_id": _supabase.auth.currentUser?.id},
      );
      for (dynamic f in data) {
        output.add(Tag.json(f));
      }
    } catch (e) {
      print(e);
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
      print(e);
      return null;
    }
  }

  Future<bool> modifyTag(String tagId, String newName, Color newColor) async {
    try {
      var data = await _supabase.rpc(
        "modify_tag",
        params: {
          "_user_id": _supabase.auth.currentUser?.id,
          "tag_id": tagId,
          "new_name": newName,
          "new_color": newColor.toARGB32(),
        },
      );
      return data;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> removeTag(String tagId) async {
    try {
      var data = await _supabase.rpc(
        "remove_tag",
        params: {"_user_id": _supabase.auth.currentUser?.id, "tag_id": tagId},
      );
      return data;
    } catch (e) {
      print(e);
      return false;
    }
  }
}
