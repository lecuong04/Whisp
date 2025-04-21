import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:whisp/models/tag.dart';

class ClassifyTabItem extends StatelessWidget {
  late final String? id;
  late final String name;
  late final Color? color;

  // ignore: prefer_const_constructors_in_immutables
  ClassifyTabItem({required this.name, this.id, this.color, super.key});
  ClassifyTabItem.tag({super.key, required Tag tag}) {
    id = tag.id;
    name = tag.name;
    color = tag.color;
  }

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          spacing: 0,
          children: [
            if (color != null) ...[
              Icon(Symbols.bookmark, fill: 1, color: color),
            ] else
              ...[],
            Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
