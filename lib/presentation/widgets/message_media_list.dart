import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:whisp/custom_cache_manager.dart';
import 'package:whisp/presentation/widgets/audio_player_modal.dart';
import 'package:whisp/presentation/widgets/image_thumbnail.dart';
import 'package:whisp/presentation/widgets/video_thumbnail.dart';
import 'package:whisp/services/chat_service.dart';
import 'package:whisp/utils/helpers.dart';

class MessageMediaList extends StatefulWidget {
  final String conversationId;

  const MessageMediaList({super.key, required this.conversationId});

  @override
  State<MessageMediaList> createState() => _MessageMediaListState();
}

class _MessageMediaListState extends State<MessageMediaList>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  static final int pageSize = 24;

  final List<Map<String, String>> filters = [
    {'key': 'all', 'name': 'Tất cả'},
    {'key': 'file', 'name': 'File'},
    {'key': 'image', 'name': 'Ảnh'},
    {'key': 'audio', 'name': 'Âm thanh'},
    {'key': 'video', 'name': 'Video'},
  ];
  late int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: filters.length, vsync: this);
    tabController.addListener(() {
      if (tabController.indexIsChanging) return;
      if (mounted) {
        setState(() {
          selectedIndex = tabController.index;
        });
      }
    });
  }

  static Widget buildMediaItem(
    String type,
    String url,
    DateTime sentAt,
    BuildContext context,
  ) {
    Widget contentWidget;
    switch (type) {
      case 'image':
        contentWidget = CachedNetworkImage(
          imageUrl: url,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          placeholder:
              (context, url) => const SizedBox(
                width: 60,
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              ),
          errorWidget: (context, url, error) => const Icon(Icons.error),
          cacheManager: CustomCacheManager(),
        );
        break;
      case 'video':
        contentWidget = const Icon(
          Icons.video_file_outlined,
          size: 60,
          color: Colors.blue,
        );
        break;
      case 'file':
        contentWidget = const Icon(
          Icons.insert_drive_file_outlined,
          size: 60,
          color: Colors.blue,
        );
        break;
      case 'audio':
        contentWidget = const Icon(
          Icons.audio_file_outlined,
          size: 60,
          color: Colors.blue,
        );
        break;
      default:
        contentWidget = const Icon(
          Icons.file_present,
          size: 60,
          color: Colors.blue,
        );
    }

    return ListTile(
      leading: contentWidget,
      title: Text(
        getFileNameFromSupabaseStorage(url),
        style: TextStyle(
          fontStyle: type == 'file' ? FontStyle.normal : FontStyle.italic,
        ),
      ),
      subtitle: Text(
        '${sentAt.day}/${sentAt.month}/${sentAt.year} ${sentAt.hour}:${sentAt.minute.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      onLongPress: () async {
        switch (type) {
          case 'file':
            if (await canLaunchUrlString(url)) {
              await launchUrlString(url);
            }
            break;
          case 'image':
            await ImageThumbnail.imageViewer(context: context, url: url);
            break;
          case 'audio':
            await showModalBottomSheet(
              context: context,
              builder: (context) => AudioPlayerModal(url: url),
            );
            break;
          case 'video':
            await VideoThumbnail.videoPlayer(context: context, url: url);
            break;
          default:
            break;
        }
      },
    );
  }

  Future<List<Widget>> getMessageContents(String key) async {
    List<Map<String, dynamic>> data = [];
    switch (key) {
      case 'all':
        {
          data = await ChatService().getListMultimedia(
            widget.conversationId,
            pageSize,
            1,
          );
          break;
        }
      case 'file':
        {
          data = await ChatService().getListFiles(
            widget.conversationId,
            pageSize,
            1,
          );
          break;
        }
      case 'image':
        {
          data = await ChatService().getListImages(
            widget.conversationId,
            pageSize,
            1,
          );
          break;
        }
      case 'audio':
        {
          data = await ChatService().getListAudio(
            widget.conversationId,
            pageSize,
            1,
          );
          break;
        }
      case 'video':
        {
          data = await ChatService().getListVideos(
            widget.conversationId,
            pageSize,
            1,
          );
          break;
        }
    }
    List<Widget> result = [];
    for (var x in data) {
      result.add(
        buildMediaItem(
          key == 'all' ? x['type'] : key,
          x['url'],
          DateTime.parse(x['sent_at']),
          context,
        ),
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          title: const Row(
            children: [Text('Kho lưu trữ', style: TextStyle(fontSize: 20))],
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            TabBar(
              controller: tabController,
              tabAlignment: TabAlignment.center,
              labelStyle: const TextStyle(fontSize: 16),
              unselectedLabelStyle: const TextStyle(fontSize: 16),
              indicatorColor: Colors.black,
              indicatorWeight: 3,
              labelColor: Colors.black,
              isScrollable: false,
              unselectedLabelColor: Colors.grey,
              tabs: filters.map((filter) => Tab(text: filter['name'])).toList(),
            ),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children:
                    filters
                        .map(
                          (filter) => FutureBuilder(
                            future: getMessageContents(filter['key']!),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return ListView(children: snapshot.requireData);
                              } else {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                            },
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }
}
