import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/presentation/screens/auth/verify_otp_screen.dart';
import 'package:whisp/presentation/widgets/custom_button.dart';
import 'package:whisp/presentation/widgets/custom_text_field.dart';
import 'package:whisp/utils/helpers.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

  // Xử lý việc gửi yêu cầu OTP đặt lại mật khẩu
  Future<void> handleSubmit() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Vui lòng nhập email')));
      return;
    }

    if (!checkEmailValid(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập email đúng định dạng')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Gọi Edge Function để gửi OTP
      final response = await Supabase.instance.client.functions.invoke(
        'send-reset-otp',
        body: {'email': email},
      );

      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Không thể gửi OTP');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mã OTP đã được gửi đến email của bạn')),
      );

      // Chuyển đến màn hình nhập OTP
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => VerifyOTPScreen(email: email)),
      );
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
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back),
                ),
                SizedBox(height: 10),
                Text(
                  'Đặt lại mật khẩu',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Vui lòng nhập email của bạn để nhận mã OTP 6 số',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: 30),
                CustomTextField(
                  controller: emailController,
                  hintText: "Email",
                  prefixIcon: const Icon(Icons.email),
                ),
                SizedBox(height: 20),
                isLoading
                    ? Center(child: CircularProgressIndicator())
                    : CustomButton(
                      onPressed: () => handleSubmit(),
                      text: 'Gửi mã OTP',
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// 