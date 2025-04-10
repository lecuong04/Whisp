bool checkEmailValid(String email) => RegExp(
  r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
).hasMatch(email);

bool checkPhoneValid(String phone) =>
    RegExp(r'(^(?:[+0]9)?[0-9]{10,12}$)').hasMatch(phone);
