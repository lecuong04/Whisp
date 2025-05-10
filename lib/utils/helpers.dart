import 'dart:math';

import 'package:intl/intl.dart';

bool checkEmailValid(String email) => RegExp(
  r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
).hasMatch(email);

bool checkPhoneValid(String phone) =>
    RegExp(r'(^(?:[+0]9)?[0-9]{10,12}$)').hasMatch(phone);

String generateOtp() {
  final random = Random();
  return (100000 + random.nextInt(900000)).toString(); // OTP 6 chữ số
}

String normalizeUsername(String input, {int maxLength = 30}) {
  // B1: Loại bỏ khoảng trắng đầu/cuối và chuyển thành chữ thường
  String username = input.trim().toLowerCase();

  // B2: Giữ lại chỉ các ký tự hợp lệ (chữ, số, _ và .)
  username = username.replaceAll(RegExp(r'[^a-z0-9._]'), '');

  // B3: Loại bỏ dấu chấm đầu/cuối hoặc dấu chấm lặp lại (tuỳ chọn, nếu muốn nghiêm ngặt hơn)
  username = username.replaceAll(
    RegExp(r'\.{2,}'),
    '.',
  ); // loại bỏ dấu chấm lặp
  username = username.replaceAll(
    RegExp(r'^\.|\.$'),
    '',
  ); // loại bỏ dấu chấm đầu/cuối

  // B4: Cắt độ dài nếu vượt quá giới hạn
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
