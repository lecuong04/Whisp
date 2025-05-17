import 'package:flutter/material.dart';
import 'package:whisp/presentation/widgets/message_media_list.dart';

class MessageMediaTab extends StatefulWidget {
  final String conversationId;

  const MessageMediaTab({super.key, required this.conversationId});

  @override
  State<MessageMediaTab> createState() => _MessageMediaTabState();
}

class _MessageMediaTabState extends State<MessageMediaTab>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  int selectedIndex = 0;

  final List<Map<String, String>> filters = [
    {'key': 'all', 'name': 'Tất cả'},
    {'key': 'file', 'name': 'File'},
    {'key': 'image', 'name': 'Ảnh'},
    {'key': 'audio', 'name': 'Âm thanh'},
    {'key': 'video', 'name': 'Video'},
  ];

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: filters.length, vsync: this);
    tabController.addListener(() {
      setState(() {
        selectedIndex = tabController.index;
      });
    });
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          title: const Text('Kho lưu trữ', style: TextStyle(fontSize: 20)),
          foregroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            TabBar(
              controller: tabController,
              tabAlignment: TabAlignment.center,
              labelStyle: const TextStyle(fontSize: 16),
              unselectedLabelStyle: const TextStyle(fontSize: 16),
              indicatorColor: Colors.black,
              indicatorWeight: 3,
              labelColor: Colors.black,
              isScrollable: true,
              unselectedLabelColor: Colors.grey,
              tabs: filters.map((filter) => Tab(text: filter['name'])).toList(),
            ),
            Expanded(
              child: IndexedStack(
                index: selectedIndex,
                children:
                    filters.map((filter) {
                      return MessageMediaList(
                        type: filter['key']!,
                        conversationId: widget.conversationId,
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
