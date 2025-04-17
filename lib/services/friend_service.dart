import 'package:supabase_flutter/supabase_flutter.dart';

class FriendService {
  Future listFriends() async {
    final SupabaseClient supabase = Supabase.instance.client;
    var data = await supabase.rpc(
      "list_friends",
      params: {"user_id": supabase.auth.currentUser?.id},
    );
    print(data);
  }
}
