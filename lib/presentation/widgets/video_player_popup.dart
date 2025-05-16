import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerPopup extends StatefulWidget {
  final Uri url;

  const VideoPlayerPopup({super.key, required this.url});

  @override
  State<StatefulWidget> createState() => _VideoPlayerPopupState();
}

class _VideoPlayerPopupState extends State<VideoPlayerPopup> {
  late VideoPlayerController videoController;
  ChewieController? chewieController;
  double volume = 1.0;

  Future<void> initializePlayer() async {
    videoController = VideoPlayerController.networkUrl(widget.url);
    await videoController.initialize();
    chewieController = ChewieController(
      videoPlayerController: videoController,
      additionalOptions: (context) {
        return [
          OptionItem(
            onTap: (context) async {
              if (await canLaunchUrl(widget.url)) {
                await launchUrl(
                  widget.url,
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            iconData: Icons.open_in_browser,
            title: "Open in browser",
          ),
        ];
      },
      autoPlay: true,
    );
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    initializePlayer();
  }

  @override
  void dispose() {
    videoController.dispose();
    chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return chewieController != null &&
            chewieController!.videoPlayerController.value.isInitialized
        ? AspectRatio(
          aspectRatio: videoController.value.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: Chewie(controller: chewieController!),
          ),
        )
        : const Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 18,
            children: [
              CircularProgressIndicator(color: Colors.grey),
              Text(
                "Đang tải...",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        );
  }
}
