import 'package:supabase_flutter/supabase_flutter.dart';

class FriendRequest {
  final String username;
  final String fullName;
  final String avatarURL;
  late String _status;

  String get status => _status;

  FriendRequest({
    required this.fullName,
    required this.username,
    required this.avatarURL,
    required String status,
  }) {
    switch (status) {
      case "":
      case "pending":
      case "accepted":
      case "rejected":
      case "blocked":
        _status = status;
        break;
      default:
        throw Exception("Invalid status!");
    }
  }

  void requestFriend() {
    var supabase = Supabase.instance.client;
    if (_status == "") {}
  }

  //FriendRequest.json(Map<String, String> data) {}
}
