import 'dart:async';
import 'dart:io';

import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:intl/intl.dart';
import 'package:whisp/custom_cache_manager.dart';

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

Future<File?> getThumbnail(
  String url, {
  int maxHeight = 0,
  int maxWidth = 0,
}) async {
  var data = await VideoThumbnail.thumbnailData(
    video: url,
    imageFormat: ImageFormat.PNG,
    maxHeight: maxHeight,
    maxWidth: maxWidth,
    quality: 100,
    timeMs: 0,
  );
  if (data.isNotEmpty) {
    return await CustomCacheManager().putFile(url, data, fileExtension: 'png');
  }
  return null;
}

String getFileNameFromSupabaseStorage(String url) {
  return Uri.decodeComponent(
    url
        .split('/')
        .last
        .replaceFirstMapped(RegExp('^\\d+_', unicode: true), (match) => ''),
  );
}

String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return '$minutes:$seconds';
}

Duration hoursToDuration(double hours) {
  final totalSeconds = (hours * 3600).round();
  return Duration(seconds: totalSeconds);
}

void runAtSpecificTime(DateTime targetTime, Function callback) {
  final now = DateTime.now();
  final delay = targetTime.difference(now);

  if (delay.isNegative) {
    print('Thời gian đã qua rồi!');
    return;
  }

  Timer(delay, () {
    callback();
  });
}
