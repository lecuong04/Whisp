import 'package:supabase_flutter/supabase_flutter.dart';

class FriendRequest {
  final _supabase = Supabase.instance.client;

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

  Future requestFriend() async {
    if (_status == "" || _status == "rejected") {
      var data = await _supabase.rpc(
        "request_friend",
        params: {
          "request_username": username,
          "user_id": _supabase.auth.currentUser?.id,
        },
      );
      _status = data.toString();
      _isYourReq = true;
    } else if (_status == "pending" && !_isYourReq) {
      var data = await _supabase.rpc(
        "accept_friend_request",
        params: {
          "self_id": _supabase.auth.currentUser?.id,
          "request_username": _username,
        },
      );
      _status = data.toString();
    }
  }

  Future rejectFriend() async {
    if (_status == "pending" && !_isYourReq) {
      var data = await _supabase.rpc(
        "reject_friend_request",
        params: {
          "self_id": _supabase.auth.currentUser?.id,
          "request_username": _username,
        },
      );
      _status = data.toString();
    }
  }
}
