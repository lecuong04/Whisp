import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:whisp/config/theme/app_theme.dart';
import 'package:whisp/presentation/screens/auth/login_screen.dart';
import 'package:whisp/presentation/screens/auth/reset_password_screen.dart';
import 'package:whisp/presentation/screens/auth/signup_screen.dart';
import 'package:whisp/presentation/screens/chats_page.dart';
import 'package:whisp/presentation/screens/friends_page.dart';
import 'package:whisp/presentation/screens/messages_screen.dart';
import 'package:whisp/presentation/screens/user/add_friend_screen.dart';
import 'package:whisp/presentation/screens/user/user_profile_screen.dart';
import 'package:whisp/presentation/screens/video_call_screen.dart';
import 'package:whisp/presentation/widgets/custom_search.dart';
import 'package:whisp/services/background_service.dart';
import 'package:whisp/services/call_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class WhispApp extends StatelessWidget {
  const WhispApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        // theme: AppTheme.lightTheme,
        routes: {
          '/sign_up': (context) => SignupScreen(),
          '/login': (context) => LoginScreen(),
          '/home': (context) => HomeScreen(),
          '/reset_password': (context) => ResetPasswordScreen(),
        },
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const LoginScreen();
    }
    return const HomeScreen();
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

  final List<Widget> pages = [
    const Chats(),
    const Friends(),
    const UserProfileScreen(),
  ];

  @override
  void initState() {
    FlutterBackgroundService().invoke("startBackground", {
      "refreshToken":
          Supabase.instance.client.auth.currentSession!.refreshToken,
    });
    if (widget.selectedIndex != null &&
        widget.selectedIndex! >= 0 &&
        widget.selectedIndex! < pages.length) {
      selectedIndex = widget.selectedIndex!;
    }
    searchController = SearchController();
    pageController = PageController(initialPage: selectedIndex);
    super.initState();
    initRoute();
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
          onPressed: () {},
          icon: const Icon(Icons.menu, size: 32),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddFriendScreen()),
              );
            },
            icon: const Icon(Icons.add, size: 32, fill: 1),
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
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Tin nhắn'),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Danh bạ',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Cá nhân'),
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

  Future<void> initRoute() async {
    var uri = await AppLinks().getInitialLink();
    if (uri == null) return;
    switch (uri.host) {
      case "messages":
        {
          if (mounted) {
            if (uri.queryParameters["type"] == "call") {
              var callInfo = await CallService().getCallInfo(
                uri.queryParameters["content"]!,
              );
              if (callInfo != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoCallScreen(callInfo: callInfo),
                  ),
                );
              }
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => MessagesScreen(
                        chatId: uri.queryParameters["conversation_id"]!,
                        contactName: uri.queryParameters["title"]!,
                        contactImage: uri.queryParameters["avatar_url"]!,
                      ),
                ),
              );
            }
          }
          break;
        }
    }
  }
}
