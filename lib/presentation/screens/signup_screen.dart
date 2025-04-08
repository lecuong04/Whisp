import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/presentation/screens/login_screen.dart';
import 'package:whisp/presentation/widgets/custom_button.dart';
import 'package:whisp/presentation/widgets/custom_text_field.dart';
import 'package:whisp/utils/helpers.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool isLoading = false;

  Future<void> handleSubmit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final username = usernameController.text.trim();
    final phone = phoneController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        username.isEmpty ||
        phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin')));
      return;
    }

    if (!checkEmailValid(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập email đúng định dạng')),
      );
      return;
    }

    if (!checkPhoneValid(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập số điện thoại đúng định dạng')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nhập lại mật khẩu không khớp với mật khẩu')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'phone': phone, 'username': username},
      );

      if (res.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng ký thành công! Vui lòng xác nhận email.'),
          ),
        );

        await Future.delayed(Duration(seconds: 2));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Có lỗi xảy ra: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Form(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 30),
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Đăng nhập để tiếp tục',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                ),
                SizedBox(height: 30),
                CustomTextField(
                  controller: emailController,
                  hintText: "Email",
                  prefixIcon: const Icon(Icons.email),
                ),
                SizedBox(height: 16),
                CustomTextField(
                  controller: usernameController,
                  hintText: "Họ và tên",
                  prefixIcon: const Icon(Icons.person),
                ),
                SizedBox(height: 16),
                CustomTextField(
                  controller: phoneController,
                  hintText: "Số điện thoại",
                  prefixIcon: const Icon(Icons.phone),
                ),
                SizedBox(height: 16),
                CustomTextField(
                  controller: passwordController,
                  hintText: "Mật khẩu",
                  obscureText: true,
                  prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: const Icon(Icons.visibility),
                ),
                SizedBox(height: 16),
                CustomTextField(
                  controller: confirmPasswordController,
                  hintText: "Nhập lại mật khẩu",
                  obscureText: true,
                  prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: const Icon(Icons.visibility),
                ),

                SizedBox(height: 20),
                isLoading
                    ? Center(child: CircularProgressIndicator())
                    : CustomButton(
                      onPressed: () => handleSubmit(),
                      text: 'Đăng ký',
                    ),

                SizedBox(height: 20),
                Center(
                  child: RichText(
                    text: TextSpan(
                      text: 'Bạn đã có tài khoản? ',
                      style: TextStyle(color: Colors.grey[600]),
                      children: [
                        TextSpan(
                          text: 'Đăng nhập ngay',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                          recognizer:
                              TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginScreen(),
                                    ),
                                  );
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
