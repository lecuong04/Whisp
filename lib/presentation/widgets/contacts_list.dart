import 'package:whisp/models/friend.dart';
import 'package:whisp/presentation/widgets/contact_title.dart';
import 'package:flutter/material.dart';
import 'package:diacritic/diacritic.dart';

class ContactsList extends StatefulWidget {
  final List<Friend> friends;
  const ContactsList(this.friends, {super.key});

  @override
  State<StatefulWidget> createState() => ContactsListState();
}

class ContactsListState extends State<ContactsList> {
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
          ContactTitle(
            fullName: f.fullName,
            avatarUrl: f.avatarUrl,
            username: f.username,
            isOnline: f.isOnline,
          ),
        );
      }
    });
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
