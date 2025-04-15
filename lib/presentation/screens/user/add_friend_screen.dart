import 'package:flutter/material.dart';
import 'package:whisp/models/friend_request.dart';
import 'package:whisp/presentation/widgets/friend_request_title.dart';
import 'package:whisp/services/friend_service.dart';

class UserModel {
  final String name;
  final String username;
  final String avatarUrl;
  bool isRequested;

  UserModel({
    required this.name,
    required this.username,
    required this.avatarUrl,
    this.isRequested = false,
  });
}

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  List<UserModel> users = [
    UserModel(
      name: 'Michael Johnson',
      username: '@michael.johnson',
      avatarUrl: 'https://i.pravatar.cc/150?img=1',
    ),
    UserModel(
      name: 'Michael Thompson',
      username: '@michael.thompson',
      avatarUrl: 'https://i.pravatar.cc/150?img=2',
    ),
    UserModel(
      name: 'Michael Rodriguez',
      username: '@michael_rodriguez',
      avatarUrl: 'https://i.pravatar.cc/150?img=3',
      isRequested: true,
    ),
    UserModel(
      name: 'Michael Wilson',
      username: '@michael.wilson',
      avatarUrl: 'https://i.pravatar.cc/150?img=4',
    ),
    UserModel(
      name: 'Michael Martinez',
      username: '@michael_martinez',
      avatarUrl: 'https://i.pravatar.cc/150?img=5',
      isRequested: true,
    ),
    UserModel(
      name: 'Michael Clark',
      username: '@michael.clark',
      avatarUrl: 'https://i.pravatar.cc/150?img=6',
    ),
    UserModel(
      name: 'Michael Bailey',
      username: '@michael_bailey',
      avatarUrl: 'https://i.pravatar.cc/150?img=7',
    ),
  ];

  int selectedTab = 1; // 0: All Friends, 1: Users

  void toggleFriendRequest(int index) {
    setState(() {
      users[index].isRequested = !users[index].isRequested;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: _buildSearchBar(),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          //_buildTabs(),
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return FriendRequestTitle(
                  request: FriendRequest(
                    fullName: user.name,
                    username: user.username,
                    avatarURL: user.avatarUrl,
                    status: "",
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back, color: Colors.black),
        ),
        SizedBox(width: 8),
        Expanded(
          child: TextField(
            onSubmitted: (value) {
              FriendService().findUsers(value);
            },
            decoration: InputDecoration(
              hintText: 'Michael',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  // Widget _buildTabs() {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  //     child: Row(
  //       children: [
  //         _tabItem("All Friends", 0),
  //         SizedBox(width: 8),
  //         _tabItem("Users", 1),
  //       ],
  //     ),
  //   );
  // }

  // Widget _tabItem(String label, int index) {
  //   final isSelected = selectedTab == index;
  //   return Expanded(
  //     child: GestureDetector(
  //       onTap: () {
  //         setState(() {
  //           selectedTab = index;
  //         });
  //       },
  //       child: Container(
  //         padding: EdgeInsets.symmetric(vertical: 10),
  //         decoration: BoxDecoration(
  //           color:
  //               isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
  //           borderRadius: BorderRadius.circular(16),
  //         ),
  //         alignment: Alignment.center,
  //         child: Text(
  //           label,
  //           style: TextStyle(
  //             color: isSelected ? Colors.white : Colors.black87,
  //             fontWeight: FontWeight.w600,
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }
}
