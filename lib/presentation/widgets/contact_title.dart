import 'package:flutter/material.dart';

class ContactTitle extends StatelessWidget {
  final String fullName;
  final bool isOnline;
  const ContactTitle({required this.fullName, required this.isOnline, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
          leading: SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(
                    "https://static.vecteezy.com/system/resources/thumbnails/029/470/675/small_2x/ai-generated-ai-generative-purple-pink-color-sunset-evening-nature-outdoor-lake-with-mountains-landscape-background-graphic-art-photo.jpg",
                  ),
                  radius: 26,
                ),
                if (isOnline) ...[
                  Align(alignment: Alignment.bottomRight, child: Stack(alignment: AlignmentDirectional.center, children: [Icon(Icons.circle, color: Colors.white, size: 18), Icon(Icons.circle, color: Colors.green, size: 14)])),
                ] else
                  ...[],
              ],
            ),
          ),
          title: Text(fullName, style: TextStyle(fontSize: 18)),
        ),
        Padding(padding: EdgeInsets.only(bottom: 8)),
      ],
    );
  }
}
