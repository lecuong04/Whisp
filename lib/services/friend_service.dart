import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/models/friend.dart';

class FriendService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Friend>> listFriends() async {
    List<Friend> output = List.empty(growable: true);
    try {
      var data = await _supabase.rpc(
        "list_friends",
        params: {"_user_id": _supabase.auth.currentUser?.id},
      );
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
    } catch (e) {
      print(e);
    }
    return output;
  }

  Future<bool> addFriendTag(String friendId, String tagId) async {
    try {
      var data = await _supabase.rpc(
        "add_tag_to_friend",
        params: {
          "_user_id": _supabase.auth.currentUser?.id,
          "friend_id": friendId,
          "tag_id": tagId,
        },
      );
      return data;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> removeFriendTag(String friendId, String tagId) async {
    try {
      var data = await _supabase.rpc(
        "remove_tag_from_friend",
        params: {
          "_user_id": _supabase.auth.currentUser?.id,
          "friend_id": friendId,
          "tag_id": tagId,
        },
      );
      return data;
    } catch (e) {
      print(e);
      return false;
    }
  }

  void subscribeToFriends(String userId, {VoidCallback? onFriendChanged}) {
    final channel = _supabase.channel('public:friendships');
    channel
        .onPostgresChanges(
          schema: 'public',
          table: 'friendships',
          event: PostgresChangeEvent.all,
          callback: (payload) async {
            if (onFriendChanged != null) {
              onFriendChanged();
            }
          },
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: "user_id1",
            value: userId,
          ),
        )
        .onPostgresChanges(
          schema: 'public',
          table: 'friendships',
          event: PostgresChangeEvent.all,
          callback: (payload) async {
            if (onFriendChanged != null) {
              onFriendChanged();
            }
          },
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: "user_id2",
            value: userId,
          ),
        )
        .subscribe();
  }
}
