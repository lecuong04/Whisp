import 'package:flutter/material.dart';

class ContactTitle extends StatelessWidget {
  final String id;
  final String fullName;
  final bool isOnline;
  final String avatarUrl;
  final String username;
  final VoidCallback? onTap;
  const ContactTitle({
    required this.id,
    required this.fullName,
    required this.isOnline,
    required this.avatarUrl,
    required this.username,
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
          leading: SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(avatarUrl),
                  radius: 26,
                ),
                if (isOnline) ...[
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Stack(
                      alignment: AlignmentDirectional.center,
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 18),
                        Icon(Icons.circle, color: Colors.green, size: 14),
                      ],
                    ),
                  ),
                ] else
                  ...[],
              ],
            ),
          ),
          title: Text(fullName, style: TextStyle(fontSize: 18)),
          subtitle: Text("@$username"),
        ),
        Padding(padding: EdgeInsets.only(bottom: 8)),
      ],
    );
  }
}
