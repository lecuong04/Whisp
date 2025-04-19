import 'package:whisp/presentation/widgets/classify_tab_item.dart';
import 'package:whisp/presentation/widgets/contacts_list.dart';
import 'package:whisp/presentation/widgets/search.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:whisp/services/friend_service.dart';

class Contacts extends StatefulWidget {
  const Contacts({super.key});

  @override
  State<StatefulWidget> createState() => ContactsState();
}

class ContactsState extends State<Contacts>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  var data = FriendService().listFriends();
  @override
  void initState() {
    tabController = TabController(length: 1, vsync: this);
    tabController.addListener(() {
      setState(() {});
    });
    FriendService().listFriends();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Search(),
          Divider(height: 0),
          Padding(padding: EdgeInsets.symmetric(vertical: 5), child: null),
          Divider(height: 0),
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
                    indicator: CustomTabIndicator(),
                    tabAlignment: TabAlignment.start,
                    isScrollable: true,
                    labelPadding: EdgeInsets.symmetric(horizontal: 5),
                    labelStyle: TextStyle(color: Colors.white),
                    unselectedLabelStyle: TextStyle(color: Colors.black),
                    controller: tabController,
                    tabs: [
                      ClassifyTabItem(name: "Tất cả"),
                      // ClassifyTabItem(name: "Gia đình", color: Colors.cyan),
                      // ClassifyTabItem(name: "Bạn thân", color: Colors.orange),
                      // ClassifyTabItem(
                      //   name: "Đồng nghiệp",
                      //   color: Colors.brown,
                      // ),
                      // ClassifyTabItem(name: "Hàng xóm", color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.only(bottom: 10)),
          Expanded(
            child: FutureBuilder(
              future: data,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [CircularProgressIndicator()],
                  );
                }
                if (snapshot.hasData) {
                  return TabBarView(
                    controller: tabController,
                    children: [
                      ContactsList(snapshot.data!),
                      // ContactsList(),
                      // ContactsList(),
                      // ContactsList(),
                      // ContactsList(),
                    ],
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

class CustomTabIndicator extends Decoration {
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return CustomPainter(this, onChanged);
  }
}

class CustomPainter extends BoxPainter {
  final double indicatorHeight = 32;
  final CustomTabIndicator decoration;

  CustomPainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

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
