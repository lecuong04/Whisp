import 'dart:ui';

class Tag {
  late final String id;
  late final String name;
  late final Color color;

  Tag(this.id, this.name, this.color);

  Tag.json(dynamic data) {
    id = data["id"];
    name = data["name"];
    color = Color(0xFF000000 | int.parse(data["color"].toString()));
  }
}
