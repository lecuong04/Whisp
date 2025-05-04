import 'dart:math';

import 'package:whisp/models/tag.dart';
import 'package:whisp/presentation/widgets/classify_tab_item.dart';
import 'package:whisp/presentation/widgets/color_slider.dart';
import 'package:whisp/presentation/widgets/friend_list.dart';
import 'package:flutter/material.dart';
import 'package:whisp/services/friend_service.dart';
import 'package:whisp/services/tag_service.dart';
import 'package:whisp/services/user_service.dart';

class Friends extends StatefulWidget {
  const Friends({super.key});

  @override
  State<StatefulWidget> createState() => _FriendsState();
}

class _FriendsState extends State<Friends> with TickerProviderStateMixin {
  late TabController tabController;
  var friends = FriendService().listFriends();
  List<ClassifyTabItem> tags = List.empty(growable: true);
  int selectedIndex = 0;

  @override
  void initState() {
    tabController = TabController(length: 1, vsync: this);
    super.initState();
    FriendService().subscribeToFriends(
      UserService().id!,
      onFriendChanged: () {
        friends = FriendService().listFriends();
        setState(() {});
      },
    );
    buildTags();
  }

  Future buildTags() async {
    tags.clear();
    for (Tag t in await TagService().listTags()) {
      tags.add(ClassifyTabItem.tag(tag: t));
    }
    tabController = TabController(length: tags.length + 1, vsync: this);
    friends = FriendService().listFriends();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 8),
          SizedBox(
            height: 46,
            child: Row(
              children: [
                IconButton(
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (context) {
                        return showTagsManagement();
                      },
                    );
                  },
                  icon: Icon(Icons.tune, fill: 1),
                ),
                VerticalDivider(width: 0),
                Expanded(
                  child: TabBar(
                    enableFeedback: false,
                    indicator: _CustomTabIndicator(),
                    tabAlignment: TabAlignment.start,
                    isScrollable: true,
                    labelPadding: EdgeInsets.symmetric(horizontal: 5),
                    labelStyle: TextStyle(color: Colors.white),
                    unselectedLabelStyle: TextStyle(color: Colors.black),
                    controller: tabController,
                    tabs: [ClassifyTabItem(name: "Tất cả"), ...tags],
                  ),
                ),
                VerticalDivider(width: 0),
                IconButton(
                  onPressed: () {
                    buildTags();
                  },
                  icon: Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.only(bottom: 10)),
          Expanded(
            child: FutureBuilder(
              future: friends,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [CircularProgressIndicator()],
                  );
                }
                if (snapshot.hasData) {
                  List<Widget> views = List.empty(growable: true);
                  views.add(
                    FriendList(
                      snapshot.data!,
                      tags: tags.map((x) => x.tag).toList(),
                      onFriendTagsChanged: () async {
                        selectedIndex = tabController.index;
                        await buildTags();
                        tabController.index = selectedIndex;
                      },
                    ),
                  );
                  for (ClassifyTabItem w in tags) {
                    views.add(
                      FriendList(
                        snapshot.data!,
                        tagId: w.id,
                        tags: tags.map((x) => x.tag).toList(),
                        onFriendTagsChanged: () async {
                          selectedIndex = tabController.index;
                          await buildTags();
                          tabController.index = selectedIndex;
                        },
                      ),
                    );
                  }
                  return TabBarView(
                    controller: tabController,
                    children: [...views],
                  );
                }
                return Container();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget showTagsManagement() {
    var screenSize = MediaQuery.of(context).size;
    return StatefulBuilder(
      builder: (context, setState) {
        List<Widget> widgets = List.empty(growable: true);
        for (ClassifyTabItem t in tags) {
          widgets.add(
            ListTile(
              contentPadding: EdgeInsets.all(0),
              title: Text(t.name),
              leading: Icon(Icons.bookmark, color: t.color, fill: 1),
              trailing: Wrap(
                children: [
                  IconButton(
                    onPressed: () async {
                      var data = await showModifyTagDialog(
                        context,
                        Tag(t.id!, t.name, t.color!),
                      );
                      if (data == null) return;
                      if (data.color == t.color && data.name == t.name) return;
                      if (await TagService().modifyTag(
                        t.id!,
                        data.name,
                        data.color,
                      )) {
                        await buildTags();
                        setState(() {});
                      }
                    },
                    icon: Icon(Icons.edit),
                  ),
                  IconButton(
                    onPressed: () async {
                      if (await TagService().removeTag(t.id!)) {
                        await buildTags();
                        setState(() {});
                      }
                    },
                    icon: Icon(Icons.delete),
                  ),
                ],
              ),
            ),
          );
        }
        return AlertDialog(
          alignment: Alignment.center,
          content: SizedBox(
            width: screenSize.width * 0.8,
            height: screenSize.height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Danh sách thẻ phân loại",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22.5),
                  ),
                ),
                Expanded(child: ListView(children: [...widgets])),
                ElevatedButton.icon(
                  onPressed: () async {
                    var data = await showAddTagDialog(context);
                    if (data == null) return;
                    if (await TagService().addTag(data.name, data.color) !=
                        null) {
                      await buildTags();
                      setState(() {});
                    }
                  },
                  label: Text("Thêm thẻ phân loại"),
                  icon: Icon(Icons.add),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Tag?> showAddTagDialog(BuildContext context) async {
    final nameController = TextEditingController();
    Color selectedColor = getRandomColor();
    FocusNode focusNode = FocusNode();
    bool isTap = false;

    return await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              contentPadding: EdgeInsets.all(16),
              titlePadding: EdgeInsets.only(top: 16),
              title: Text('Thêm thẻ phân loại', textAlign: TextAlign.center),
              content: SingleChildScrollView(
                child: ListBody(
                  children: [
                    Row(
                      crossAxisAlignment:
                          isTap || nameController.text.isNotEmpty
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                isTap || nameController.text.isNotEmpty ? 4 : 0,
                          ),
                          child: Icon(
                            Icons.bookmark,
                            size: 32,
                            fill: 1,
                            color: selectedColor,
                          ),
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            onTap: () {
                              isTap = true;
                              setState(() {});
                            },
                            onChanged: (value) {
                              setState(() {});
                            },
                            controller: nameController,
                            focusNode: focusNode,
                            onTapOutside: (event) {
                              isTap = false;
                              focusNode.unfocus();
                              setState(() {});
                            },
                            decoration: InputDecoration(labelText: 'Tên'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: 300,
                      child: ColorSlider(
                        color: selectedColor,
                        onColorChanged: (color) {
                          selectedColor = color;
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed:
                      nameController.text.isEmpty
                          ? null
                          : () {
                            final name = nameController.text.trim();
                            if (name.isEmpty) return;
                            Navigator.pop(
                              context,
                              Tag("", name, selectedColor),
                            );
                          },
                  child: Text('Thêm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color getRandomColor() {
    final Random random = Random();
    return HSVColor.fromAHSV(1, random.nextInt(361).toDouble(), 1, 1).toColor();
  }

  Future<Tag?> showModifyTagDialog(BuildContext context, Tag tag) async {
    final nameController = TextEditingController();
    Color selectedColor = tag.color;
    FocusNode focusNode = FocusNode();

    nameController.text = tag.name;

    return await showDialog(
      context: context,
      builder: (context) {
        bool isTap = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              contentPadding: EdgeInsets.all(16),
              titlePadding: EdgeInsets.only(top: 16),
              title: Text('Sửa thẻ phân loại', textAlign: TextAlign.center),
              content: Wrap(
                alignment: WrapAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment:
                        isTap || nameController.text.isNotEmpty
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              isTap || nameController.text.isNotEmpty ? 4 : 0,
                        ),
                        child: Icon(
                          Icons.bookmark,
                          size: 32,
                          fill: 1,
                          color: selectedColor,
                        ),
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          onTap: () {
                            isTap = true;
                            setState(() {});
                          },
                          onChanged: (value) {
                            setState(() {});
                          },
                          controller: nameController,
                          focusNode: focusNode,
                          onTapOutside: (event) {
                            isTap = false;
                            focusNode.unfocus();
                            setState(() {});
                          },
                          decoration: InputDecoration(labelText: 'Tên'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: 300,
                    child: ColorSlider(
                      color: selectedColor,
                      onColorChanged: (color) {
                        selectedColor = color;
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed:
                      nameController.text.isEmpty
                          ? null
                          : () {
                            final name = nameController.text.trim();
                            if (name.isEmpty) return;
                            Navigator.pop(
                              context,
                              Tag("", name, selectedColor),
                            );
                          },
                  child: Text('Thay đổi'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CustomTabIndicator extends Decoration {
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _CustomPainter(this, onChanged);
  }
}

class _CustomPainter extends BoxPainter {
  final double indicatorHeight = 32;
  final _CustomTabIndicator decoration;

  _CustomPainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration.size != null);
    final Rect rect =
        Offset(
          offset.dx,
          (configuration.size!.height / 2) - indicatorHeight / 2,
        ) &
        Size(configuration.size!.width, indicatorHeight);
    final Paint paint = Paint();
    paint.color = Colors.blueAccent;
    paint.style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(20.0)),
      paint,
    );
  }
}
