import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:whisp/custom_cache_manager.dart';
import 'package:whisp/presentation/widgets/audio_player_modal.dart';
import 'package:whisp/presentation/widgets/image_thumbnail.dart';
import 'package:whisp/presentation/widgets/video_thumbnail.dart';
import 'package:whisp/services/chat_service.dart';
import 'package:whisp/utils/helpers.dart';

class MessageMedia extends StatefulWidget {
  final String type;
  final String conversationId;

  const MessageMedia({
    super.key,
    required this.type,
    required this.conversationId,
  });

  @override
  State<StatefulWidget> createState() => _MessageMediaState();
}

class _MessageMediaState extends State<MessageMedia>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static final int pageSize = 16;

  late final pagingController = PagingController<int, Widget>(
    getNextPageKey: (state) {
      if (state.pages == null) {
        return 1;
      } else {
        if (state.pages!.last.isEmpty) {
          return null;
        } else {
          return (state.keys?.last ?? 0) + 1;
        }
      }
    },
    fetchPage: (pageKey) async {
      return await getMessageMultimedia(
        type: widget.type,
        context: context,
        conversationId: widget.conversationId,
        page: pageKey,
      );
    },
  );

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
        style: TextStyle(fontStyle: FontStyle.normal),
      ),
      subtitle: Text(
        '${sentAt.day}/${sentAt.month}/${sentAt.year} ${sentAt.hour}:${sentAt.minute.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      onLongPress: () async {
        switch (type) {
          case 'file':
            if (await canLaunchUrlString(url)) {
              await launchUrlString(url, mode: LaunchMode.externalApplication);
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
        }
      },
    );
  }

  static Future<List<Widget>> getMessageMultimedia({
    required String type,
    required String conversationId,
    required BuildContext context,
    required int page,
  }) async {
    List<Map<String, dynamic>> data = [];
    switch (type) {
      case 'all':
        {
          data = await ChatService().getListMultimedia(
            conversationId,
            pageSize,
            page,
          );
          break;
        }
      case 'file':
        {
          data = await ChatService().getListFiles(
            conversationId,
            pageSize,
            page,
          );
          break;
        }
      case 'image':
        {
          data = await ChatService().getListImages(
            conversationId,
            pageSize,
            page,
          );
          break;
        }
      case 'audio':
        {
          data = await ChatService().getListAudio(
            conversationId,
            pageSize,
            page,
          );
          break;
        }
      case 'video':
        {
          data = await ChatService().getListVideos(
            conversationId,
            pageSize,
            page,
          );
          break;
        }
    }
    List<Widget> result = [];
    for (var x in data) {
      result.add(
        buildMediaItem(
          type == 'all' ? x['type'] : type,
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
    super.build(context);
    return RefreshIndicator(
      child: PagingListener(
        controller: pagingController,
        builder: (context, state, fetchNextPage) {
          return PagedListView(
            state: state,
            fetchNextPage: fetchNextPage,
            builderDelegate: PagedChildBuilderDelegate(
              firstPageProgressIndicatorBuilder:
                  (context) => const Center(child: CircularProgressIndicator()),
              newPageProgressIndicatorBuilder:
                  (context) => const SizedBox.shrink(),
              noItemsFoundIndicatorBuilder:
                  (context) => const SizedBox.shrink(),
              itemBuilder: (context, item, index) {
                return item as Widget;
              },
            ),
          );
        },
      ),
      onRefresh: () async => pagingController.refresh(),
    );
  }
}
