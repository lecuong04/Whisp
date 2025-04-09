import 'package:whisp/presentation/widgets/classify_tab_item.dart';
import 'package:whisp/presentation/widgets/contacts_list.dart';
import 'package:whisp/presentation/widgets/search.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class Contacts extends StatefulWidget {
  const Contacts({super.key});

  @override
  State<StatefulWidget> createState() => ContactsState();
}

class ContactsState extends State<Contacts> with SingleTickerProviderStateMixin {
  late TabController tabController;
  @override
  void initState() {
    tabController = TabController(length: 5, vsync: this);
    tabController.addListener(() {
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Search(),
          Divider(height: 0),
          SizedBox(
            height: 46,
            child: Row(
              children: [
                IconButton(onPressed: () {}, icon: Icon(Symbols.mode_edit, fill: 1)),
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
                      ClassifyTabItem(name: "Gia đình", color: Colors.cyan),
                      ClassifyTabItem(name: "Bạn thân", color: Colors.orange),
                      ClassifyTabItem(name: "Đồng nghiệp", color: Colors.brown),
                      ClassifyTabItem(name: "Hàng xóm", color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.only(bottom: 10)),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [ContactsList(), ContactsList(), ContactsList(), ContactsList(), ContactsList()],
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
        Offset(offset.dx, (configuration.size!.height / 2) - indicatorHeight / 2) &
        Size(configuration.size!.width, indicatorHeight);
    final Paint paint = Paint();
    paint.color = Colors.blueAccent;
    paint.style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(20.0)), paint);
  }
}
