import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class CustomSearch extends StatefulWidget {
  final int? page;
  const CustomSearch({super.key, this.page});

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
        builder: (BuildContext context, SearchController controller) {
          return SearchBar(
            controller: controller,
            leading: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Symbols.search, size: 24),
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
              setState(() {});
            },
            onTapOutside: (e) {
              focus.unfocus();
              setState(() {});
            },
            onTap: () {},
            trailing: [
              if (controller.text.isNotEmpty) ...[
                IconButton(
                  onPressed: () {
                    controller.clear();
                    focus.unfocus();
                    setState(() {});
                  },
                  icon: Icon(Symbols.close),
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
          return [];
        },
      ),
    );
  }
}
