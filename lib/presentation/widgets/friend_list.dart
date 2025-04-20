import 'package:whisp/main.dart';
import 'package:whisp/models/friend.dart';
import 'package:whisp/presentation/widgets/friend_title.dart';
import 'package:flutter/material.dart';
import 'package:diacritic/diacritic.dart';

class FriendList extends StatefulWidget {
  final List<Friend> friends;
  const FriendList(this.friends, {super.key});

  @override
  State<StatefulWidget> createState() => _FriendListState();
}

class _FriendListState extends State<FriendList> {
  final TextStyle charStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    Map<String, List<Friend>> grouped = {};
    for (Friend user in widget.friends) {
      String lastString = user.fullName.split(" ").last;
      String lastChar =
          (lastString.isEmpty)
              ? ""
              : removeDiacritics(lastString.substring(0, 1)).toUpperCase();
      if (RegExp("[a-z]|[A-Z]").hasMatch(lastChar)) {
        if (grouped[lastChar] == null) {
          grouped[lastChar] = List.empty(growable: true);
        }
        grouped[lastChar]!.add(user);
      } else {
        if (grouped["#"] == null) {
          grouped["#"] = List.empty(growable: true);
        }
        grouped["#"]!.add(user);
      }
    }
    grouped = Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    grouped.forEach((key, value) {
      children.add(
        Padding(
          padding: EdgeInsets.only(bottom: 4, top: 12),
          child: Text(key, style: charStyle),
        ),
      );
      for (Friend f in value) {
        children.add(
          FriendTitle(
            friend: f,
            onLongPress: () {
              showDialog(
                context: context,
                builder:
                    (context) => SimpleDialog(
                      contentPadding: EdgeInsets.all(10),
                      title: Row(
                        spacing: 10,
                        children: [
                          CircleAvatar(
                            backgroundImage: NetworkImage(f.avatarUrl),
                          ),
                          Text(f.fullName),
                        ],
                      ),
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            if (await f.remove()) {
                              Navigator.pop(context);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => HomeScreen(selectedIndex: 1),
                                ),
                              );
                            }
                          },
                          child: Text("Hủy kết bạn"),
                        ),
                      ],
                    ),
              );
            },
          ),
        );
      }
    });
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: ListView.builder(
        itemCount: children.length,
        itemBuilder: (context, index) {
          return children[index];
        },
      ),
    );
  }
}
