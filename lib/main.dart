import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:whisp/config/theme/app_theme.dart';
import 'package:whisp/presentation/screens/auth/login_screen.dart';
import 'package:whisp/presentation/screens/auth/reset_password_screen.dart';
import 'package:whisp/presentation/screens/chats_page.dart';
import 'package:whisp/presentation/screens/friends_page.dart';
import 'package:whisp/presentation/screens/user/add_friend_screen.dart';
import 'package:whisp/presentation/screens/user/user_profile_screen.dart';
import 'package:whisp/presentation/widgets/custom_search.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://${dotenv.env['SUPABASE_PROJECT_ID']}.supabase.co',
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const WhispApp());
}

class WhispApp extends StatefulWidget {
  const WhispApp({Key? key}) : super(key: key);

  @override
  _WhispAppState createState() => _WhispAppState();
}

class _WhispAppState extends State<WhispApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  Future<void> _initDeepLinkListener() async {
    // Xử lý deep link khi app được mở bằng deep link
    final appLink = await _appLinks.getInitialAppLink();
    _handleDeepLink(appLink?.toString());

    // Lắng nghe deep link khi app đang chạy
    _appLinks.uriLinkStream.listen((Uri? uri) {
      _handleDeepLink(uri?.toString());
    });
  }

  void _handleDeepLink(String? link) {
    if (link == null) return;

    // Kiểm tra nếu link liên quan đến đặt lại mật khẩu
    if (link.contains('reset-callback')) {
      // Điều hướng đến màn hình đặt lại mật khẩu
      Navigator.of(context).pushNamed('/reset_password');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // theme: AppTheme.lightTheme,
      routes: {
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/reset_password': (context) => ResetPasswordScreen(),
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Kiểm tra trạng thái đăng nhập
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const LoginScreen(); // Nếu chưa đăng nhập, hiển thị màn hình đăng nhập
    }
    return const HomeScreen(); // Nếu đã đăng nhập, hiển thị màn hình chính
  }
}

class HomeScreen extends StatefulWidget {
  final int? selectedIndex;
  const HomeScreen({super.key, this.selectedIndex});

  @override
  State<StatefulWidget> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;

  // Danh sách các màn hình tương ứng với từng tab
  final List<Widget> _pages = [
    const Chats(),
    const Friends(),
    const UserProfileScreen(),
  ];

  @override
  void initState() {
    if (widget.selectedIndex != null &&
        widget.selectedIndex! >= 0 &&
        widget.selectedIndex! < _pages.length) {
      _selectedIndex = widget.selectedIndex!;
    }
    _pageController = PageController(initialPage: _selectedIndex);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Whisp",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            // Xử lý sự kiện khi nhấn vào menu
          },
          icon: const Icon(Symbols.menu, size: 32),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddFriendScreen()),
              );
            },
            icon: const Icon(Symbols.add_2_rounded, size: 32, fill: 1),
          ),
        ],
        bottom:
            _selectedIndex != 2
                ? PreferredSize(
                  preferredSize: Size(double.infinity, 64),
                  child: CustomSearch(),
                )
                : null,
      ),
      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(),
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Symbols.chat), label: 'Tin nhắn'),
          BottomNavigationBarItem(
            icon: Icon(Symbols.contacts),
            label: 'Danh bạ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Symbols.person),
            label: 'Cá nhân',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            _pageController.jumpToPage(_selectedIndex);
          });
        },
      ),
    );
  }
}
