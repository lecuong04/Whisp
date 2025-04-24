import 'package:material_symbols_icons/symbols.dart';
import 'package:whisp/models/friend.dart';
import 'package:whisp/models/tag.dart';
import 'package:whisp/presentation/widgets/friend_title.dart';
import 'package:flutter/material.dart';
import 'package:diacritic/diacritic.dart';
import 'package:whisp/services/friend_service.dart';

class FriendList extends StatefulWidget {
  final String? tagId;
  final List<Tag>? tags;
  final List<Friend> friends;
  final VoidCallback? onFriendTagsChanged;
  const FriendList(
    this.friends, {
    super.key,
    this.tagId,
    this.tags,
    this.onFriendTagsChanged,
  });

  @override
  State<StatefulWidget> createState() => _FriendListState();
}

class _FriendListState extends State<FriendList> {
  late List<Friend> friends;
  final TextStyle charStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  @override
  void initState() {
    friends = widget.friends;
    if (widget.tagId != null && widget.tagId!.isNotEmpty) {
      friends =
          widget.friends.where((x) => x.tags.contains(widget.tagId)).toList();
    } else {
      friends = widget.friends;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    Map<String, List<Friend>> grouped = {};
    for (Friend user in friends) {
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
                            backgroundImage:
                                f.avatarUrl.isNotEmpty
                                    ? NetworkImage(f.avatarUrl)
                                    : null,
                          ),
                          Text(f.fullName),
                        ],
                      ),
                      children: [
                        if (widget.tagId == null || widget.tagId!.isEmpty) ...[
                          ElevatedButton(
                            onPressed: () async {
                              await showEditTagsDialog(
                                context,
                                widget.tags ?? List.empty(),
                                f.tags,
                                (data) async {
                                  data = Map.fromEntries(
                                    data.entries.where(
                                      (x) =>
                                          !(f.tags.contains(x.key) && x.value),
                                    ),
                                  );
                                  var fSer = FriendService();
                                  for (var x in data.entries) {
                                    if (x.value) {
                                      await fSer.addFriendTag(f.id, x.key);
                                      f.tags.add(x.key);
                                    } else {
                                      await fSer.removeFriendTag(f.id, x.key);
                                      f.tags.remove(x.key);
                                    }
                                  }
                                  if (widget.onFriendTagsChanged != null) {
                                    widget.onFriendTagsChanged!();
                                  }
                                },
                              );
                            },
                            child: Text("Danh sách phân loại"),
                          ),
                        ],
                        ElevatedButton(
                          onPressed: () async {
                            if (await f.remove()) {
                              Navigator.pop(context);
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

  Future<void> showEditTagsDialog(
    BuildContext context,
    List<Tag> allTags,
    List<String> friendTagIds,
    Function(Map<String, bool>) onTagsUpdated,
  ) async {
    Map<String, bool> result = {
      for (var e in allTags.map((x) => x.id)) e: friendTagIds.contains(e),
    };
    var screenSize = MediaQuery.of(context).size;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Danh sách phân loại', textAlign: TextAlign.center),
              content: SizedBox(
                width: screenSize.width * 0.8,
                height: screenSize.height * 0.2,
                child: ListView(
                  children: [
                    for (Tag t in allTags) ...[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.all(0),
                        title: Text(t.name),
                        secondary: Icon(
                          Symbols.bookmark,
                          fill: 1,
                          color: t.color,
                        ),
                        value: result[t.id],
                        onChanged: (value) {
                          result[t.id] = value ?? false;
                          setState(() {});
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onTagsUpdated(
                      Map.fromEntries(
                        result.entries.where(
                          (x) => friendTagIds.contains(x.key) || x.value,
                        ),
                      ),
                    ); // callback để cập nhật
                    Navigator.pop(context);
                  },
                  child: Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
