import 'dart:ui';

class Tag {
  late final String id;
  late final String name;
  late final Color color;

  Tag(this.id, this.name, this.color);

  Tag.map(Map<String, dynamic> data) {
    id = data["id"];
    name = data["name"];
    color = Color(int.parse(data["color"].toString()));
  }
}
