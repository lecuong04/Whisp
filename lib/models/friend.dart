import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/services/user_service.dart';

class Friend {
  final String id;
  final String username;
  final String fullName;
  final String avatarUrl;
  final List<String> tags;
  late final bool isOnline;

  Friend(
    this.id,
    this.username,
    this.fullName,
    this.avatarUrl,
    String status,
    this.tags,
  ) {
    if (status == "offline") {
      isOnline = false;
    } else {
      isOnline = true;
    }
  }

  Future<bool> remove() async {
    var supabase = Supabase.instance.client;
    var data = await supabase.rpc(
      "remove_friend",
      params: {"self_id": UserService().id, "friend_id": id},
    );
    return data;
  }
}
