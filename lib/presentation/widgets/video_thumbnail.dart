import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:whisp/presentation/widgets/video_player_popup.dart';
import 'package:whisp/utils/helpers.dart';

class VideoThumbnail extends StatefulWidget {
  final String url;
  final bool isTargetMessage;

  const VideoThumbnail({
    super.key,
    required this.url,
    required this.isTargetMessage,
  });

  @override
  State<StatefulWidget> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static int maxWidth = 240;

  Size size = Size(0, 0);
  Uint8List? data;

  Future<void> initData() async {
    File? thumbnail = await getThumbnail(widget.url, maxWidth: maxWidth);
    if (thumbnail != null) {
      data = await thumbnail.readAsBytes();
      size = ImageSizeGetter.getSizeResult(MemoryInput(data!)).size;
    }
    setState(() {});
  }

  @override
  void initState() {
    initData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return data == null
        ? SizedBox(
          width: size.width.toDouble(),
          height: size.height.toDouble(),
          child: const Padding(
            padding: EdgeInsets.all(15),
            child: Center(child: CircularProgressIndicator()),
          ),
        )
        : Container(
          decoration:
              widget.isTargetMessage
                  ? BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 3),
                    borderRadius: BorderRadius.circular(10),
                  )
                  : null,
          child: GestureDetector(
            onTap: () async {
              final url = Uri.parse(widget.url);
              await showAdaptiveDialog(
                barrierDismissible: true,
                context: context,
                builder:
                    (context) => Dialog(
                      backgroundColor: Colors.transparent,
                      child: VideoPlayerPopup(url: url),
                    ),
              );
            },
            child:
                data!.isNotEmpty
                    ? Stack(
                      alignment: AlignmentDirectional.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            data!,
                            width: size.width.toDouble(),
                            height: size.height.toDouble(),
                            gaplessPlayback: true,
                          ),
                        ),
                        Icon(
                          Icons.play_circle_filled,
                          size:
                              min(
                                size.width.toDouble(),
                                size.height.toDouble(),
                              ) /
                              3,
                          color: Colors.black54,
                        ),
                      ],
                    )
                    : Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        spacing: 12,
                        children: [
                          Icon(Icons.error),
                          Text("Không thể tải video..."),
                        ],
                      ),
                    ),
          ),
        );
  }
}
