import 'dart:io';

import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

bool checkEmailValid(String email) => RegExp(
  r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
).hasMatch(email);

String normalizeUsername(String input, {int maxLength = 30}) {
  String username = input.trim().toLowerCase();
  username = username.replaceAll(RegExp(r'[^a-z0-9._]'), '');
  username = username.replaceAll(RegExp(r'\.{2,}'), '.');
  username = username.replaceAll(RegExp(r'^\.|\.$'), '');
  if (username.length > maxLength) {
    username = username.substring(0, maxLength);
  }
  return username;
}

String dateTimeFormat(DateTime dateTime, bool is24HourFormat) {
  DateFormat formatter;
  DateTime curr = DateTime.now();
  if (curr.day == dateTime.day &&
      curr.month == dateTime.month &&
      curr.year == dateTime.year) {
    if (is24HourFormat) {
      formatter = DateFormat().add_Hm();
    } else {
      formatter = DateFormat().add_jm();
    }
  } else if (curr.year == dateTime.year) {
    formatter = DateFormat("MM/dd");
  } else {
    formatter = DateFormat("MM/dd/yy");
  }
  return formatter.format(dateTime);
}

Future<XFile?> getThumbnail(String url, int maxWidth) async {
  var thumbnailFolder = Directory(
    join((await getApplicationCacheDirectory()).path, "video_thumbnails"),
  );
  if (!thumbnailFolder.existsSync()) {
    thumbnailFolder.createSync();
  }
  final String thumbnailPath = '${thumbnailFolder.path}/${url.hashCode}.png';
  if (File(thumbnailPath).existsSync()) {
    return XFile(thumbnailPath);
  }
  await VideoThumbnail.thumbnailFile(
    video: url,
    thumbnailPath: thumbnailPath,
    imageFormat: ImageFormat.PNG,
    maxWidth: maxWidth,
    quality: 100,
    timeMs: 0,
  );
  return XFile(thumbnailPath);
}
