import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/models/call_info.dart';

class CallService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<CallInfo?> makeCallRequest(
    String otherId,
    int timeout,
    bool isVideoCall,
  ) async {
    try {
      String userId = _supabase.auth.currentUser!.id;
      var data =
          await _supabase
              .rpc(
                "make_call_request",
                params: {
                  "caller_id": userId,
                  "receiver_id": otherId,
                  "is_video_call": isVideoCall,
                },
              )
              .single();
      return CallInfo.map(data);
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<CallInfo?> getCallInfo(String callId) async {
    try {
      var data =
          await _supabase
              .rpc("get_call_info", params: {"call_id": callId})
              .single();
      return CallInfo.map(data);
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<void> endCall(String callId) async {
    try {
      await _supabase.rpc(
        "end_call",
        params: {
          'call_id': callId,
          'request_user': _supabase.auth.currentUser!.id,
        },
      );
    } catch (e) {
      print(e);
    }
  }

  Future<bool> acceptCall(String callId) async {
    try {
      return await _supabase.rpc(
        "accept_call",
        params: {
          'call_id': callId,
          'request_user': _supabase.auth.currentUser!.id,
        },
      );
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<void> updateCallWhenClick(String callId) async {
    try {
      await _supabase.rpc(
        "update_call_when_click",
        params: {
          'call_id': callId,
          'user_query': _supabase.auth.currentUser!.id,
        },
      );
    } catch (e) {
      print(e);
    }
  }
}
