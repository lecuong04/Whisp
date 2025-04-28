import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
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
import 'package:whisp/services/background_service.dart';

GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: 'https://${dotenv.env['SUPABASE_PROJECT_ID']}.supabase.co',
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await startBackgroundService();
  runApp(const WhispApp());
}

class WhispApp extends StatefulWidget {
  const WhispApp({super.key});

  @override
  State createState() => _WhispAppState();
}

class _WhispAppState extends State<WhispApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
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
  State<StatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  late PageController pageController;
  late SearchController searchController;

  // Danh sách các màn hình tương ứng với từng tab
  final List<Widget> pages = [
    const Chats(),
    const Friends(),
    const UserProfileScreen(),
  ];

  @override
  void initState() {
    FlutterBackgroundService().invoke("startBackground", {
      "userId": Supabase.instance.client.auth.currentUser!.id,
    });
    if (widget.selectedIndex != null &&
        widget.selectedIndex! >= 0 &&
        widget.selectedIndex! < pages.length) {
      selectedIndex = widget.selectedIndex!;
    }
    searchController = SearchController();
    pageController = PageController(initialPage: selectedIndex);
    super.initState();
  }

  @override
  void dispose() {
    pageController.dispose();
    searchController.dispose();
    super.dispose();
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
            selectedIndex != 2
                ? PreferredSize(
                  preferredSize: Size(double.infinity, 64),
                  child: CustomSearch(
                    page: selectedIndex,
                    controller: searchController,
                  ),
                )
                : null,
      ),
      body: PageView(
        controller: pageController,
        physics: NeverScrollableScrollPhysics(),
        children: pages,
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
        currentIndex: selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            searchController.clear();
            selectedIndex = index;
            pageController.jumpToPage(selectedIndex);
          });
        },
      ),
    );
  }
}
