import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:whisp/presentation/screens/chats.dart';
import 'package:whisp/presentation/screens/contacts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: Scaffold(
        appBar: AppBar(
          title: Text("Whisp", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28)),
          centerTitle: true,
          leading: IconButton(onPressed: () {}, icon: Icon(Symbols.menu, size: 32)),
          actions: [IconButton(onPressed: () {}, icon: Icon(Symbols.add_2_rounded, size: 32, fill: 1))],
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(icon: Icon(Symbols.chat), label: 'Tin nhắn'),
            BottomNavigationBarItem(icon: Icon(Symbols.contacts), label: 'Danh bạ'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blue,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
      ),
    );
  }
}
