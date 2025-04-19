import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:whisp/models/friend_request.dart';
import 'package:whisp/presentation/widgets/friend_request_title.dart';
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

class _AddFriendScreenState extends State<AddFriendScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  Future<List<FriendRequest>> data = Future.value(List.empty());
  TextEditingController txtSearchController = TextEditingController();
  String tmpSearch = "";
  bool isReadOnly = false;

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: _buildSearchBar(txtSearchController, (value) {
          setState(() {
            data = UserService().findUsers(value);
          });
        }),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          onTap: (value) {
            if (value == 1) {
              tmpSearch = txtSearchController.text;
              txtSearchController.clear();
              isReadOnly = true;
            } else {
              txtSearchController.text = tmpSearch;
              isReadOnly = false;
            }
            setState(() {});
          },
          controller: _tabController,
          tabs: [
            Tab(text: "Tìm kiếm người dùng"),
            Tab(text: "Chờ kết bạn"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            child: _buildFindUsers(data),
            onRefresh: () async {
              setState(() {
                data = UserService().findUsers(txtSearchController.text);
              });
            },
          ),
          _buidRequestUsers(),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
    TextEditingController controller,
    ValueChanged<String>? onSubmitted,
  ) {
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
            enabled: !isReadOnly,
            controller: controller,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: '',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              suffixIcon:
                  controller.text.isNotEmpty
                      ? IconButton(
                        onPressed: () {
                          setState(() {
                            controller.clear();
                          });
                        },
                        icon: Icon(Symbols.close),
                      )
                      : null,
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFindUsers(Future<List<FriendRequest>> data) {
    return FutureBuilder(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(padding: EdgeInsets.only(top: 10)),
                  CircularProgressIndicator(),
                ],
              ),
            ],
          );
        }
        if (snapshot.hasData) {
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final request = snapshot.data![index];
              return FriendRequestTitle(request: request);
            },
          );
        }
        return Container();
      },
    );
  }

  Widget _buidRequestUsers() {
    var data = UserService().listFriendRequest();
    return RefreshIndicator(
      child: _buildFindUsers(data),
      onRefresh: () async {
        setState(() {
          data = UserService().listFriendRequest();
        });
      },
    );
  }
}
