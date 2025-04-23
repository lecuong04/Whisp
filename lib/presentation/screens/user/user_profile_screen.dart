import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with AutomaticKeepAliveClientMixin<UserProfileScreen> {
  @override
  bool get wantKeepAlive => true;

  final user = Supabase.instance.client.auth.currentUser;

  String? fullName;
  String? username;

  String? avatarUrl;
  Future<void> handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Xác nhận đăng xuất'),
            content: Text('Bạn có chắc chắn muốn đăng xuất không?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Đăng xuất'),
              ),
            ],
          ),
    );

    if (shouldLogout == true) {
      await Supabase.instance.client.auth.signOut();

      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đăng xuất thành công')));
    }
  }

  Future<void> pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    // Crop ảnh
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Chỉnh sửa ảnh',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: true,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(title: 'Chỉnh sửa ảnh', aspectRatioLockEnabled: true),
      ],
    );

    if (croppedFile == null) return;

    final file = File(croppedFile.path);
    final fileExt = croppedFile.path.split('.').last;
    final fileName = '${user!.id}.$fileExt';

    final storage = Supabase.instance.client.storage;
    final avatarPath = 'public/$fileName';

    await storage
        .from('avatars')
        .upload(avatarPath, file, fileOptions: const FileOptions(upsert: true));

    final url = storage.from('avatars').getPublicUrl(avatarPath);

    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {'avatar_url': url}),
    );

    setState(() {
      avatarUrl = url;
    });
  }

  Future<void> handleUpdateInfo() async {
    // Kiểm tra user có tồn tại không
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể lấy thông tin người dùng')),
      );
      return;
    }

    final userData = user!.userMetadata ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return EditProfileModal(
          fullName: userData["full_name"]?.toString() ?? '',
          username: userData["username"]?.toString() ?? '',
          onSave: (data) async {
            try {
              await Supabase.instance.client.auth.updateUser(
                UserAttributes(data: data),
              );

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cập nhật thông tin thành công'),
                  ),
                );
                setState(() {
                  fullName = data["full_name"] ?? "";
                  username = data["username"] ?? "";
                }); // cập nhật giao diện
              }
            } catch (e) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Lỗi khi cập nhật thông tin: ${e.toString()}',
                    ),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    avatarUrl = user?.userMetadata?['avatar_url'];
    fullName = user?.userMetadata!["full_name"];
    username = user?.userMetadata?["username"];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                backgroundImage:
                    avatarUrl != null && avatarUrl!.isNotEmpty
                        ? NetworkImage(avatarUrl!)
                        : null,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 16,
                    child: Icon(Icons.camera_alt, size: 18, color: Colors.grey),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tên và Email
            Text(
              fullName ?? "",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email as String,
              style: TextStyle(color: Colors.grey[600]),
            ),

            const SizedBox(height: 24),

            // Thông tin cá nhân
            _buildInfoTile(
              Icons.person_outline_rounded,
              'Họ và tên',
              fullName ?? 'Cập nhật ngay',
            ),
            _buildInfoTile(
              Icons.person,
              'Username',
              username ?? 'Cập nhật ngay',
            ),

            const SizedBox(height: 30),

            // Nút chỉnh sửa
            ElevatedButton.icon(
              onPressed: () async {
                await handleUpdateInfo();
              },
              icon: Icon(Icons.edit),
              label: Text('Chỉnh sửa thông tin'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
              ),
            ),

            const SizedBox(height: 16),

            // Nút đăng xuất
            ElevatedButton.icon(
              onPressed: () => handleLogout(context),
              icon: Icon(Icons.logout),
              label: Text('Đăng xuất'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.blue),
          title: Text(label),
          subtitle: Text(value),
        ),
        Divider(),
      ],
    );
  }
}

class EditProfileModal extends StatefulWidget {
  final String fullName;
  final String username;
  final Function(Map<String, dynamic>) onSave;

  const EditProfileModal({
    super.key,
    required this.fullName,
    required this.username,
    required this.onSave,
  });

  @override
  State<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<EditProfileModal> {
  late TextEditingController _usernameController;
  late TextEditingController _fullNameController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.username);
    _fullNameController = TextEditingController(text: widget.fullName);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Chỉnh sửa thông tin',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _fullNameController,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
            keyboardType: TextInputType.text, // Sửa thành text thay vì phone
          ),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              widget.onSave({
                'full_name': _fullNameController.text,
                'username': _usernameController.text,
              });
            },
            child: Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
