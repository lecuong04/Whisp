import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/presentation/screens/auth/signup_screen.dart';
import 'package:whisp/presentation/screens/chats.dart';
// import 'package:whisp/presentation/screens/chats_page.dart';
import 'package:whisp/presentation/screens/user/user_profile_screen.dart';
import 'package:whisp/presentation/widgets/custom_button.dart';
import 'package:whisp/presentation/widgets/custom_text_field.dart';
import 'package:whisp/utils/helpers.dart';

// Login thành công => data user lưu trong Supabase.instance.client.auth.currentUser
// Supabase.instance.client.auth.currentSession chứa token: access_token, refresh_token

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> handleSubmit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin')));
      return;
    }

    if (!checkEmailValid(email)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vui lòng nhập email đúng định dạng')));
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);

      if (res.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đăng nhập thành công.')));

        await Future.delayed(Duration(seconds: 2));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UserProfileScreen()));
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email hoặc mật khẩu không chính xác')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Có lỗi xảy ra: $e')));
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
                Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text('Đăng nhập để tiếp tục', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
                SizedBox(height: 30),
                CustomTextField(controller: emailController, hintText: "Email", prefixIcon: const Icon(Icons.email)),
                SizedBox(height: 16),
                CustomTextField(controller: passwordController, hintText: "Mật khẩu", obscureText: true, prefixIcon: Icon(Icons.lock_outline), suffixIcon: const Icon(Icons.visibility)),
                SizedBox(height: 20),
                isLoading ? Center(child: CircularProgressIndicator()) : CustomButton(onPressed: () => handleSubmit(), text: 'Đăng nhập'),
                SizedBox(height: 20),
                Center(
                  child: RichText(
                    text: TextSpan(
                      text: 'Bạn chưa có tài khoản? ',
                      style: TextStyle(color: Colors.grey[600]),
                      children: [
                        TextSpan(
                          text: 'Đăng ký ngay',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500),
                          recognizer:
                              TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen()));
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
