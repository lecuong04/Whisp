import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whisp/custom_cache_manager.dart';
import 'package:whisp/utils/helpers.dart';

class MessageBlock extends StatefulWidget {
  final Map<String, dynamic> message;
  final String? targetMessageId;
  final double maxWidth;

  const MessageBlock({
    super.key,
    this.targetMessageId,
    required this.message,
    required this.maxWidth,
  });

  @override
  State<StatefulWidget> createState() => _MessageBlockState();
}

class _MessageBlockState extends State<MessageBlock>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<Widget>? data;

  static Future<Widget> buildMessageContent(
    Map<String, dynamic> message,
    String? targetMessageId,
    double maxWidth,
  ) async {
    final messageType = message['message_type'] as String;
    final content = message['content'] as String;
    final isTargetMessage = message['id'] == targetMessageId;

    Widget contentWidget;
    switch (messageType) {
      case 'image':
        {
          contentWidget = Container(
            decoration:
                isTargetMessage
                    ? BoxDecoration(
                      border: Border.all(
                        color: Colors.blue,
                        width: 3, // Viền đậm cho tin nhắn mục tiêu
                      ),
                      borderRadius: BorderRadius.circular(10),
                    )
                    : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: content,
                width: 200,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => SizedBox.square(
                      dimension: 128,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                errorWidget: (context, url, error) => const Icon(Icons.error),
                cacheManager: CustomCacheManager(),
              ),
            ),
          );
          break;
        }
      case 'video':
        {
          XFile thumbnail =
              (await getThumbnail(content, 240)) ??
              XFile.fromData(Uint8List(0));
          var result =
              ImageSizeGetter.getSizeResult(
                MemoryInput(await thumbnail.readAsBytes()),
              ).size;
          contentWidget = Container(
            decoration:
                isTargetMessage
                    ? BoxDecoration(
                      border: Border.all(
                        color: Colors.blue,
                        width: 3, // Viền đậm cho tin nhắn mục tiêu
                      ),
                      borderRadius: BorderRadius.circular(10),
                    )
                    : null,
            child: GestureDetector(
              onTap: () async {
                final url = Uri.parse(content);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: Stack(
                alignment: AlignmentDirectional.center,
                children: [
                  Image.memory(
                    await thumbnail.readAsBytes(),
                    width: result.width.toDouble(),
                    height: result.height.toDouble(),
                    gaplessPlayback: true,
                  ),
                  Icon(
                    Icons.play_circle_filled,
                    size:
                        min(result.width.toDouble(), result.height.toDouble()) /
                        3,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          );
          break;
        }
      case 'file':
        {
          contentWidget = GestureDetector(
            onTap: () async {
              final url = Uri.parse(content);
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.insert_drive_file, color: Colors.blue),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      content.split('/').last,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isTargetMessage
                                ? FontWeight.bold
                                : FontWeight
                                    .normal, // In đậm nếu là tin nhắn mục tiêu
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
          break;
        }
      case 'call':
        {
          final callInfo = message['call_info'] as Map<String, dynamic>?;
          if (callInfo == null) {
            contentWidget = Text(
              'Cuộc gọi không xác định',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    isTargetMessage
                        ? FontWeight.bold
                        : FontWeight.normal, // In đậm nếu là tin nhắn mục tiêu
              ),
            );
          } else {
            final isVideoCall = callInfo['is_video_call'] as bool;
            final status = callInfo['status'] as String;
            String displayText;
            IconData icon;

            switch (status) {
              case 'accepted':
                displayText = "Cuộc gọi đang diễn ra";
                icon = isVideoCall ? Icons.videocam : Icons.phone;
                break;
              case 'ended':
                displayText =
                    isVideoCall
                        ? 'Cuộc gọi video đã kết thúc'
                        : 'Cuộc gọi đã kết thúc';
                icon = isVideoCall ? Icons.videocam : Icons.phone;
                break;
              case 'missed':
                displayText =
                    isVideoCall ? 'Cuộc gọi video nhỡ' : 'Cuộc gọi nhỡ';
                icon = isVideoCall ? Icons.videocam_off : Icons.phone_missed;
                break;
              case 'rejected':
                displayText =
                    isVideoCall
                        ? 'Cuộc gọi video bị từ chối'
                        : 'Cuộc gọi bị từ chối';
                icon = isVideoCall ? Icons.videocam_off : Icons.phone_missed;
                break;
              case 'pending':
                displayText = "Cuộc gọi chờ chấp nhận";
                icon = isVideoCall ? Icons.videocam : Icons.phone;
                break;
              default:
                displayText = 'Cuộc gọi không xác định';
                icon = Icons.phone;
            }

            contentWidget = Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color:
                        status == 'missed' || status == "rejected"
                            ? Colors.red
                            : Colors.blue,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isTargetMessage
                                ? FontWeight.bold
                                : FontWeight
                                    .normal, // In đậm nếu là tin nhắn mục tiêu
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }
          break;
        }
      case 'text':
      default:
        {
          contentWidget = Text(
            content,
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  isTargetMessage
                      ? FontWeight.bold
                      : FontWeight.normal, // In đậm nếu là tin nhắn mục tiêu
            ),
          );
          break;
        }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: contentWidget,
    );
  }

  @override
  void initState() {
    data = buildMessageContent(
      widget.message,
      widget.targetMessageId,
      widget.maxWidth,
    );
    super.initState();
  }

  @override
  void didUpdateWidget(covariant MessageBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message['id'] != oldWidget.message['id']) {
      data = buildMessageContent(
        widget.message,
        widget.targetMessageId,
        widget.maxWidth,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.requireData;
        } else {
          return Padding(
            padding: EdgeInsets.all(15),
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}
