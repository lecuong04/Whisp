import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final user = Supabase.instance.client.auth.currentUser;

  String? avatarUrl;

  Future<void> handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Xác nhận đăng xuất'),
            content: Text('Bạn có chắc chắn muốn đăng xuất không?'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Hủy')), ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Đăng xuất'))],
          ),
    );

    if (shouldLogout == true) {
      await Supabase.instance.client.auth.signOut();

      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đăng xuất thành công')));
    }
  }

  Future<void> pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final fileExt = pickedFile.path.split('.').last;
    final fileName = '${user!.id}.$fileExt';

    final storage = Supabase.instance.client.storage;
    final avatarPath = 'public/$fileName';

    // Upload lên Supabase Storage
    await storage.from('avatars').upload(avatarPath, file, fileOptions: const FileOptions(upsert: true));

    // Lấy public URL
    final url = storage.from('avatars').getPublicUrl(avatarPath);

    // Cập nhật metadata
    await Supabase.instance.client.auth.updateUser(UserAttributes(data: {'avatar_url': url}));

    setState(() {
      avatarUrl = url;
    });
  }

  @override
  void initState() {
    super.initState();
    avatarUrl = user?.userMetadata?['avatar_url'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            GestureDetector(
              onTap: pickAndUploadAvatar,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : AssetImage('assets/default_avatar.png') as ImageProvider,
                child: Align(alignment: Alignment.bottomRight, child: CircleAvatar(backgroundColor: Colors.white, radius: 16, child: Icon(Icons.camera_alt, size: 18, color: Colors.grey))),
              ),
            ),

            const SizedBox(height: 16),

            // Tên và Email
            Text(user?.userMetadata?["username"] ?? "Cập nhật ngay", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(user?.email as String, style: TextStyle(color: Colors.grey[600])),

            const SizedBox(height: 24),

            // Thông tin cá nhân
            _buildInfoTile(Icons.phone, 'Số điện thoại', user?.userMetadata?["phone"] ?? 'Cập nhật ngay'),
            _buildInfoTile(Icons.location_on, 'Địa chỉ', user?.userMetadata?['address'] ?? 'Cập nhật ngay'),
            _buildInfoTile(Icons.cake, 'Ngày sinh', user?.userMetadata?['dayOfBirth'] ?? 'Cập nhật ngay'),

            const SizedBox(height: 30),

            // Nút chỉnh sửa
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to edit profile
              },
              icon: Icon(Icons.edit),
              label: Text('Chỉnh sửa thông tin'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 48)),
            ),

            const SizedBox(height: 16),

            // Nút đăng xuất
            OutlinedButton.icon(onPressed: () => handleLogout(context), icon: Icon(Icons.logout), label: Text('Đăng xuất'), style: OutlinedButton.styleFrom(minimumSize: Size(double.infinity, 48))),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Column(children: [ListTile(leading: Icon(icon, color: Colors.blue), title: Text(label), subtitle: Text(value)), Divider()]);
  }
}
