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

  void requestFriend() async {
    final supabase = Supabase.instance.client;
    if (_status == "") {
      var data = await supabase.rpc(
        "request_friend",
        params: {
          "request_username": username,
          "user_id": supabase.auth.currentUser?.id,
        },
      );
      _status = data.toString();
    }
  }

  //FriendRequest.json(Map<String, String> data) {}
}
