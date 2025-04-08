import 'package:whisp/presentation/widgets/chat_title.dart';
import 'package:whisp/presentation/widgets/search.dart';
import 'package:flutter/material.dart';

class Chats extends StatefulWidget {
  const Chats({super.key});

  @override
  State<StatefulWidget> createState() => ChatsState();
}

class ChatsState extends State<Chats> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Search(),
          Divider(height: 0),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: ListView(
                scrollDirection: Axis.vertical,
                padding: EdgeInsets.only(bottom: 10),
                children: [
                  ChatTitle(
                    "https://static.vecteezy.com/system/resources/thumbnails/029/470/675/small_2x/ai-generated-ai-generative-purple-pink-color-sunset-evening-nature-outdoor-lake-with-mountains-landscape-background-graphic-art-photo.jpg",
                    "Lê Ngọc Cường",
                    DateTime.now(),
                    true,
                    true,
                    "1",
                  ),
                  ChatTitle(
                    "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTDsou-9Yj0s2NTQ1pGx4zvMQj12BW1NUvgLA&s",
                    "Nguyễn Trọng Hiếu",
                    DateTime(2024, 4, 2),
                    false,
                    false,
                    "2",
                  ),
                  ChatTitle(
                    "https://thumbs.dreamstime.com/b/incredibly-beautiful-sunset-sun-lake-sunrise-landscape-panorama-nature-sky-amazing-colorful-clouds-fantasy-design-115177001.jpg",
                    "Thạch Quốc Điền",
                    DateTime(2025, 2, 28),
                    false,
                    true,
                    "3",
                  ),
                  ChatTitle(
                    "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcStLCIGSn1EvhGu0o-wsTDXhg2HfYZmuyWUbbphvL5ZNVpg6voeGqq2Sw4YlPdwMXRwh7Q&usqp=CAU",
                    "Trần Minh Hà",
                    DateTime(2025, 3, 20),
                    true,
                    false,
                    "4",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
