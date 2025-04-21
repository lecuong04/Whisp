import 'package:whisp/models/tag.dart';
import 'package:whisp/presentation/widgets/classify_tab_item.dart';
import 'package:whisp/presentation/widgets/friend_list.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:whisp/services/friend_service.dart';

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

  void buildTags() async {
    for (Tag t in await FriendService().listTags()) {
      tags.add(ClassifyTabItem.tag(tag: t));
    }
    tabController = TabController(length: tags.length + 1, vsync: this);
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
                  onPressed: () {},
                  icon: Icon(Symbols.mode_edit, fill: 1),
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
                    RefreshIndicator(
                      child: FriendList(snapshot.data!),
                      onRefresh: () async {
                        friends = FriendService().listFriends();
                        setState(() {});
                      },
                    ),
                  );
                  for (ClassifyTabItem w in tags) {
                    views.add(
                      RefreshIndicator(
                        child: FriendList(snapshot.data!, tagId: w.id),
                        onRefresh: () async {
                          friends = FriendService().listFriends();
                          setState(() {});
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
