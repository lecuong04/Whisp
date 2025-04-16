import 'package:supabase_flutter/supabase_flutter.dart';

class FriendRequest {
  final String fullName;
  final String username;
  late String _avatarURL;
  late String _status;

  String get status => _status;
  String get avatarURL => _avatarURL;

  FriendRequest({
    required this.fullName,
    required this.username,
    required String? avatarURL,
    required String? status,
  }) {
    _avatarURL = (avatarURL ??= "");
    status ??= "";
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
