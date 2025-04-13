import 'package:flutter/material.dart';

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

class FriendRequestScreen extends StatefulWidget {
  @override
  _FriendRequestScreenState createState() => _FriendRequestScreenState();
}

class _FriendRequestScreenState extends State<FriendRequestScreen> {
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
          _buildTabs(),
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(user.avatarUrl),
                  ),
                  title: Text(
                    user.name,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    user.username,
                    style: TextStyle(color: Colors.grey),
                  ),
                  trailing: GestureDetector(
                    onTap: () => toggleFriendRequest(index),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            user.isRequested
                                ? Colors.grey[100]
                                : Color(0xFFFF8654),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            user.isRequested
                                ? Border.all(color: Colors.grey)
                                : null,
                      ),
                      child: Text(
                        user.isRequested ? 'Đã gửi' : 'Kết bạn',
                        style: TextStyle(
                          color: user.isRequested ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
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
        Icon(Icons.arrow_back, color: Colors.black),
        SizedBox(width: 8),
        Expanded(
          child: TextField(
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

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          _tabItem("All Friends", 0),
          SizedBox(width: 8),
          _tabItem("Users", 1),
        ],
      ),
    );
  }

  Widget _tabItem(String label, int index) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = index;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFFFF8654) : Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
