import 'package:flutter/material.dart';
import 'package:whisp/models/friend.dart';
import 'package:whisp/presentation/widgets/friend_title.dart';
import 'package:whisp/services/friend_service.dart';

class CustomSearch extends StatefulWidget {
  final int page;
  final SearchController controller;
  const CustomSearch({super.key, required this.page, required this.controller});

  @override
  State<StatefulWidget> createState() => _CustomSearchState();
}

class _CustomSearchState extends State<CustomSearch> {
  FocusNode focus = FocusNode();

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 10, right: 10, bottom: 10),
      child: SearchAnchor(
        searchController: widget.controller,
        builder: (BuildContext context, SearchController controller) {
          return SearchBar(
            controller: controller,
            leading: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.search, size: 24),
            ),
            focusNode: focus,
            hintText: "Tìm kiếm...",
            hintStyle: WidgetStatePropertyAll(TextStyle(fontSize: 16)),
            textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 16)),
            elevation: WidgetStatePropertyAll(0),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onChanged: (value) {
              controller.openView();
            },
            onTapOutside: (e) {
              focus.unfocus();
              setState(() {});
            },
            onTap: () {
              controller.openView();
            },
            trailing: [
              if (controller.text.isNotEmpty) ...[
                IconButton(
                  onPressed: () {
                    controller.clear();
                    focus.unfocus();
                    setState(() {});
                  },
                  icon: Icon(Icons.close),
                ),
              ] else
                ...[],
            ],
          );
        },
        suggestionsBuilder: (
          BuildContext context,
          SearchController controller,
        ) {
          int p = widget.page;
          switch (p) {
            case 0:
              {
                break;
              }
            case 1:
              return searchFriends(controller.text);
          }
          return [];
        },
      ),
    );
  }

  Future<List<Widget>> searchFriends(String search) async {
    if (search.length < 2) return [];
    return [
      for (Friend f in await FriendService().searchFriends(search)) ...[
        FriendTitle(friend: f),
      ],
    ];
  }
}
