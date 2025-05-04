class CallInfo {
  late final String id;
  late final String callerId;
  late final String receiverId;
  late final DateTime createdAt;
  late final String status;
  late final int timeout;
  late final bool isVideoCall;
  late final Map<String, dynamic>? iceServers;

  CallInfo(
    this.id,
    this.callerId,
    this.receiverId,
    this.createdAt,
    this.status,
    this.timeout,
    this.isVideoCall, {
    this.iceServers,
  });

  CallInfo.map(Map<String, dynamic> data) {
    id = data["id"];
    callerId = data["caller_id"];
    receiverId = data["receiver_id"];
    createdAt = DateTime.parse(data["created_at"]);
    isVideoCall = data["is_video_call"];
    iceServers = data["ice_servers"];
    status = data['status'];
    timeout = data['timeout'];
  }
}
