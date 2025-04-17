import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  // Lấy thông tin người dùng bằng RPC
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    final SupabaseClient _supabase = Supabase.instance.client;
    try {
      final response =
          await _supabase
              .rpc('get_user_info', params: {'p_user_id': userId})
              .single();

      return {
        'username': response['username'] as String? ?? userId,
        'avatar_url':
            response['avatar_url'] as String? ??
            'https://via.placeholder.com/150',
      };
    } catch (e) {
      print('Error fetching user info via RPC: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> findUsers(String username) async {
    final SupabaseClient supabase = Supabase.instance.client;
    if (username.length < 2) return List.empty();
    var data = await supabase.rpc(
      "find_users",
      params: {"search": username, "user_id": supabase.auth.currentUser?.id},
    );
    List<Map<String, dynamic>> result = List.empty(growable: true);
    for (var item in data) {
      print(item);
      result.add(item);
    }
    return result;
  }
}
