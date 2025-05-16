import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:whisp/custom_cache_manager.dart';

class AudioPlayerModal extends StatefulWidget {
  final String url;
  const AudioPlayerModal({super.key, required this.url});

  @override
  State<StatefulWidget> createState() => _AudioPlayerModalState();
}

class _AudioPlayerModalState extends State<AudioPlayerModal> {
  final AudioPlayer player = AudioPlayer();
  bool isLoaded = false;

  Duration duration = Duration();
  Duration position = Duration();

  bool get isPlaying => player.state == PlayerState.playing;

  void initStreams() {
    player.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() => duration = d);
      }
    });

    player.onPositionChanged.listen((p) {
      print("Audio Player Position: $p");
      if (mounted && p <= duration) {
        setState(() => position = p);
      }
    });

    player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() => position = Duration.zero);
      }
    });
  }

  void setupPlayer() async {
    var data = await CustomCacheManager().downloadFile(widget.url);
    if (data.file.existsSync()) {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setPlaybackRate(1);
      await player.setSourceDeviceFile(data.file.path);
      duration = (await player.getDuration())!;
      position = (await player.getCurrentPosition())!;
      setState(() {
        isLoaded = true;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    initStreams();
    setupPlayer();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    const iconSize = 40.0;
    var title = widget.url
        .split('/')
        .last
        .replaceFirstMapped(RegExp('^\\d+_', unicode: true), (match) => '');
    return !isLoaded
        ? const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        )
        : Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                maxLines: 1,
                title,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
              Slider(
                min: 0,
                max: duration.inMilliseconds.toDouble(),
                onChanged:
                    (value) =>
                        player.seek(Duration(milliseconds: value.round())),
                value: position.inMilliseconds.toDouble(),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDuration(position),
                    style: TextStyle(fontSize: 16),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed:
                            () => player.seek(position - Duration(seconds: 10)),
                        icon: Icon(Icons.replay_10),
                        iconSize: iconSize,
                      ),
                      IconButton(
                        onPressed:
                            () => isPlaying ? player.pause() : player.resume(),
                        icon: Icon(!isPlaying ? Icons.play_arrow : Icons.pause),
                        iconSize: iconSize,
                      ),
                      IconButton(
                        onPressed:
                            () => player.seek(position + Duration(seconds: 10)),
                        icon: Icon(Icons.forward_10),
                        iconSize: iconSize,
                      ),
                    ],
                  ),
                  Text(
                    formatDuration(duration),
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        );
  }
}
