import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ClassifyTabItem extends StatelessWidget {
  final String name;
  final Color? color;

  const ClassifyTabItem({required this.name, this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          spacing: 0,
          children: [
            if (color != null) ...[Icon(Symbols.bookmark, fill: 1, color: color)] else ...[],
            Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
