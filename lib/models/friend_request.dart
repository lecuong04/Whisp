import 'package:supabase_flutter/supabase_flutter.dart';

class FriendRequest {
  late String _fullName;
  late String _username;
  late String _avatarURL;
  late String _status;
  late bool _isYourReq;

  bool get isYourRequest => _isYourReq;
  String get fullName => _fullName;
  String get username => _username;
  String get status => _status;
  String get avatarURL => _avatarURL;

  FriendRequest({
    required String fullName,
    required String username,
    required bool isYourRequest,
    required String? avatarURL,
    required String? status,
  }) {
    _fullName = fullName;
    _username = username;
    _avatarURL = (avatarURL ??= "");
    _isYourReq = isYourRequest;
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
    if (_status == "" || _status == "rejected") {
      var data = await supabase.rpc(
        "request_friend",
        params: {
          "request_username": username,
          "user_id": supabase.auth.currentUser?.id,
        },
      );
      _status = data.toString();
    } else if (_status == "pending") {
      if (!_isYourReq) {
        var data = await supabase.rpc(
          "accept_friend_request",
          params: {
            "self_id": supabase.auth.currentUser?.id,
            "request_username": _username,
          },
        );
        _status = data.toString();
      }
    }
  }

  FriendRequest.json(dynamic data) {
    _fullName = data["full_name"];
    _username = data["username"];
    _avatarURL = data["avatar_url"] ?? "";
    _isYourReq = data["is_your_request"] ?? false;
    String status = data["status"] ?? "";
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
}
