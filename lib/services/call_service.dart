import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/models/call_info.dart';

class CallService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<CallInfo?> makeCallRequest(
    String otherId,
    int timeout,
    bool videoEnabled,
  ) async {
    try {
      String userId = _supabase.auth.currentUser!.id;
      var data =
          await _supabase
              .rpc(
                "make_call_request",
                params: {
                  "self_id": userId,
                  "other_id": otherId,
                  "timeout": timeout,
                  "video_enabled": videoEnabled,
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
}
