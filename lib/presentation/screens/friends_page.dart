import 'package:whisp/models/tag.dart';
import 'package:whisp/presentation/widgets/classify_tab_item.dart';
import 'package:whisp/presentation/widgets/friend_list.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:whisp/services/friend_service.dart';
import 'package:whisp/services/tag_service.dart';

class Friends extends StatefulWidget {
  const Friends({super.key});

  @override
  State<StatefulWidget> createState() => _FriendsState();
}

class _FriendsState extends State<Friends>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<Friends> {
  @override
  bool get wantKeepAlive => true;

  late TabController tabController;
  var friends = FriendService().listFriends();
  List<ClassifyTabItem> tags = List.empty(growable: true);

  @override
  void initState() {
    tabController = TabController(length: 1, vsync: this);
    tabController.addListener(() {
      setState(() {});
    });
    super.initState();
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
    super.build(context);

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1),
          SizedBox(
            height: 46,
            child: Row(
              children: [
                IconButton(
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (context) {
                        var screenSize = MediaQuery.of(context).size;
                        return StatefulBuilder(
                          builder: (context, sfSetState) {
                            List<Widget> widgets = List.empty(growable: true);
                            for (ClassifyTabItem t in tags) {
                              widgets.add(
                                ListTile(
                                  contentPadding: EdgeInsets.all(0),
                                  title: Text(t.name),
                                  leading: Icon(
                                    Symbols.bookmark,
                                    color: t.color,
                                    fill: 1,
                                  ),
                                  trailing: Wrap(
                                    children: [
                                      IconButton(
                                        onPressed: () {},
                                        icon: Icon(Symbols.edit),
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          if (await TagService().removeTag(
                                            t.id!,
                                          )) {
                                            await buildTags();
                                            sfSetState(() {});
                                          }
                                        },
                                        icon: Icon(Symbols.delete),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return Dialog(
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: screenSize.width * 0.8,
                                height: screenSize.height * 0.6,
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          "Quản lý thẻ phân loại",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 24,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: ListView(children: [...widgets]),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {},
                                        label: Text("Thêm thẻ phân loại"),
                                        icon: Icon(Symbols.add),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                  icon: Icon(Symbols.tune, fill: 1),
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
                  icon: Icon(Symbols.refresh),
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
                  views.add(FriendList(snapshot.data!));
                  for (ClassifyTabItem w in tags) {
                    views.add(FriendList(snapshot.data!, tagId: w.id));
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
