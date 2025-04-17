import 'package:flutter/material.dart';
import 'package:whisp/models/friend_request.dart';
import 'package:whisp/presentation/widgets/friend_request_title.dart';
import 'package:whisp/services/friend_service.dart';
import 'package:whisp/services/user_service.dart';

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
  Future<List<Map<String, dynamic>>> data = Future.value(List.empty());

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FutureBuilder(
              future: data,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [CircularProgressIndicator()],
                  );
                }
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final user = snapshot.data![index];
                      return FriendRequestTitle(
                        request: FriendRequest(
                          fullName: user["full_name"],
                          username: user["username"],
                          avatarURL: user["avatar_url"],
                          status: user["status"],
                        ),
                      );
                    },
                  );
                } else {
                  return Container();
                }
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
              setState(() {
                data = UserService().findUsers(value);
              });
            },
            decoration: InputDecoration(
              hintText: '',
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
}
