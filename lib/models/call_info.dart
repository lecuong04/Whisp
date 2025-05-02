class CallInfo {
  late final String id;
  late final String callerId;
  late final String calleeId;
  late final DateTime createdAt;
  late final DateTime expiresAt;
  late final bool videoEnabled;

  CallInfo(
    this.id,
    this.callerId,
    this.calleeId,
    this.createdAt,
    this.expiresAt,
    this.videoEnabled,
  );

  CallInfo.map(Map<String, dynamic> data) {
    id = data["id"];
    callerId = data["caller_id"];
    calleeId = data["callee_id"];
    createdAt = DateTime.parse(data["created_at"]);
    expiresAt = DateTime.parse(data["expires_at"]);
    videoEnabled = data["video_enabled"];
  }
}
