import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Lấy thông tin người dùng bằng RPC
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final response = await _supabase.rpc('get_user_info', params: {'p_user_id': userId}).single();

      return {'username': response['username'] as String? ?? userId, 'avatar_url': response['avatar_url'] as String? ?? 'https://via.placeholder.com/150'};
    } catch (e) {
      print('Error fetching user info via RPC: $e');
      return null;
    }
  }
}
