import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/presentation/widgets/custom_button.dart';
import 'package:whisp/presentation/widgets/custom_text_field.dart';
import 'package:flutter/services.dart';

class VerifyOTPScreen extends StatefulWidget {
  final String email;

  const VerifyOTPScreen({super.key, required this.email});

  @override
  State createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final TextEditingController otpController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool isLoading = false;

  Future<void> handleSubmit() async {
    final otp = otpController.text.trim();
    final newPassword = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    // Kiểm tra dữ liệu đầu vào
    if (otp.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin')));
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mật khẩu không khớp')));
      return;
    }

    if (otp.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mã OTP phải có 6 số')));
      return;
    }

    setState(() => isLoading = true);

    try {
      // Gọi Edge Function để xác thực OTP và đặt lại mật khẩu
      final response = await Supabase.instance.client.functions.invoke(
        'verify-reset-otp',
        body: {'email': widget.email, 'otp': otp, 'newPassword': newPassword},
      );

      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Không thể xác thực OTP');
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đặt lại mật khẩu thành công')));

      // Quay về màn hình đăng nhập
      await Future.delayed(Duration(seconds: 2));
      Navigator.of(context).popUntil((route) => route.isFirst);
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
    otpController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back),
                ),
                SizedBox(height: 10),
                Text(
                  'Xác thực OTP',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Nhập mã OTP 6 số đã được gửi đến ${widget.email}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: 30),
                _buildOTPFields(),
                SizedBox(height: 20),
                CustomTextField(
                  controller: passwordController,
                  hintText: 'Mật khẩu mới',
                  obscureText: true,
                  prefixIcon: Icon(Icons.lock),
                ),
                SizedBox(height: 16),
                CustomTextField(
                  controller: confirmPasswordController,
                  hintText: 'Xác nhận mật khẩu',
                  obscureText: true,
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                SizedBox(height: 24),
                isLoading
                    ? Center(child: CircularProgressIndicator())
                    : CustomButton(
                      text: 'Xác nhận & đặt lại mật khẩu',
                      onPressed: handleSubmit,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tạo UI cho nhập OTP với 6 ô riêng biệt
  Widget _buildOTPFields() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          6,
          (index) => Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              onChanged: (value) {
                // Tự động chuyển focus sang ô tiếp theo khi đã nhập
                if (value.length == 1 && index < 5) {
                  FocusScope.of(context).nextFocus();
                }

                // Cập nhật giá trị OTP
                String currentOtp = otpController.text;
                if (currentOtp.length <= index) {
                  // Thêm vào cuối
                  otpController.text = currentOtp + value;
                } else {
                  // Thay thế ký tự tại vị trí index
                  String newOtp =
                      currentOtp.substring(0, index) +
                      value +
                      (index < currentOtp.length - 1
                          ? currentOtp.substring(index + 1)
                          : '');
                  otpController.text = newOtp;
                }
              },
              decoration: InputDecoration(
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        ),
      ),
    );
  }
}
