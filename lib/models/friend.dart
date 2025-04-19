class Friend {
  final String id;
  final String username;
  final String fullName;
  final String avatarUrl;
  late final bool isOnline;

  Friend(this.id, this.username, this.fullName, this.avatarUrl, String status) {
    if (status == "offline") {
      isOnline = false;
    } else {
      isOnline = true;
    }
  }

  @override
  String toString() {
    return "$id | @$username | $fullName";
  }
}
