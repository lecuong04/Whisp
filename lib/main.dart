import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisp/config/theme/app_theme.dart';
import 'package:whisp/presentation/screens/auth/login_screen.dart';
import 'package:whisp/presentation/screens/chats_page.dart';
import 'package:whisp/presentation/screens/contacts_page.dart';
import 'package:whisp/presentation/screens/auth/signup_screen.dart';
import 'package:whisp/presentation/screens/user/user_profile_screen.dart';
import 'package:whisp/presentation/screens/video_call_screen.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  Supabase.initialize(
    url: 'https://${dotenv.env['SUPABASE_PROJECT_ID']}.supabase.co',
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const Home());
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<StatefulWidget> createState() => HomeState();
}

class HomeState extends State<Home> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [Chats(), Contacts()];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routes: {
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
      },
      initialRoute: '/login',
      // home: Scaffold(
      //   appBar: AppBar(
      //     title: Text("Whisp", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28)),
      //     centerTitle: true,
      //     leading: IconButton(onPressed: () {}, icon: Icon(Symbols.menu, size: 32)),
      //     actions: [IconButton(onPressed: () {}, icon: Icon(Symbols.add_2_rounded, size: 32, fill: 1))],
      //   ),
      //   body: _pages[_selectedIndex],
      //   bottomNavigationBar: BottomNavigationBar(
      //     items: [
      //       BottomNavigationBarItem(icon: Icon(Symbols.chat), label: 'Tin nhắn'),
      //       BottomNavigationBarItem(icon: Icon(Symbols.contacts), label: 'Danh bạ'),
      //     ],
      //     currentIndex: _selectedIndex,
      //     selectedItemColor: Colors.blue,
      //     onTap: (index) {
      //       setState(() {
      //         _selectedIndex = index;
      //       });
      //     },
      //   ),
      // ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebRTC Supabase',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(), // Màn hình chính ban đầu
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _roomIdController = TextEditingController();

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  void _joinRoom() {
    final roomId = _roomIdController.text.trim();
    if (roomId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(roomId: roomId),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng nhập ID phòng')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhập ID Phòng')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _roomIdController,
              decoration: const InputDecoration(
                labelText: 'Room ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _joinRoom,
              child: const Text('Tham gia phòng'),
            ),
          ],
        ),
      ),
    );
  }
}
