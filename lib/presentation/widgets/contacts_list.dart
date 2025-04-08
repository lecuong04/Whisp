import 'package:whisp/presentation/widgets/contact_title.dart';
import 'package:flutter/material.dart';
import 'package:diacritic/diacritic.dart';

class ContactsList extends StatefulWidget {
  const ContactsList({super.key});

  @override
  State<StatefulWidget> createState() => ContactsListState();
}

class ContactsListState extends State<ContactsList> {
  final List<String> users = ["Lê Ngọc Cường", "Thạch Quốc Điền", "Nguyễn Trọng Hiếu", "Trần Minh Hà"];
  final TextStyle charStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black);

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    Map<String, List<String>> grouped = {};
    for (String user in users) {
      String lastString = user.split(" ").last;
      String lastChar = (lastString.isEmpty) ? "" : removeDiacritics(lastString.substring(0, 1)).toUpperCase();
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
    grouped = Map.fromEntries(grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    grouped.forEach((key, value) {
      children.add(Padding(padding: EdgeInsets.only(bottom: 4, top: 12), child: Text(key, style: charStyle)));
      for (String user in value) {
        children.add(ContactTitle(fullName: user, isOnline: true));
      }
    });
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }
}
