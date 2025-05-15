import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:url_launcher/url_launcher_string.dart';

class DurationState {
  final Duration position;
  final Duration buffered;
  final Duration total;

  DurationState({
    required this.position,
    required this.buffered,
    required this.total,
  });
}

class AudioPlayerModal extends StatefulWidget {
  final String url;
  const AudioPlayerModal({super.key, required this.url});

  @override
  State<StatefulWidget> createState() => _AudioPlayerModalState();
}

class _AudioPlayerModalState extends State<AudioPlayerModal> {
  late Stream<DurationState> durationState;
  final AudioPlayer player = AudioPlayer();
  bool isLoaded = false;

  void setupPlayer() async {
    await player.setUrl(widget.url);
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.ready) {
        isLoaded = true;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void initState() {
    setupPlayer();
    super.initState();
    durationState =
        Rx.combineLatest3<Duration, Duration, Duration?, DurationState>(
          player.positionStream,
          player.bufferedPositionStream,
          player.durationStream,
          (position, buffered, total) => DurationState(
            position: position,
            buffered: buffered,
            total: total ?? Duration.zero,
          ),
        );
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
              Tooltip(
                message: title,
                child: Text(
                  maxLines: 1,
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StreamBuilder<DurationState>(
                stream: durationState,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  final position = state?.position ?? Duration.zero;
                  final total = state?.total ?? Duration.zero;

                  return Column(
                    children: [
                      Slider(
                        min: 0.0,
                        max: total.inMilliseconds.toDouble(),
                        value:
                            position.inMilliseconds
                                .clamp(0, total.inMilliseconds)
                                .toDouble(),
                        onChanged: (value) {
                          player.seek(Duration(milliseconds: value.toInt()));
                        },
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatDuration(position)),
                          StreamBuilder<PlayerState>(
                            stream: player.playerStateStream,
                            builder: (context, snapshot) {
                              final inState = snapshot.data;
                              final isPlaying = inState?.playing ?? false;
                              final processing = inState?.processingState;

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.replay_10),
                                    iconSize: 30,
                                    onPressed: () async {
                                      Duration tmp =
                                          player.position -
                                          const Duration(seconds: 10);
                                      await player.seek(
                                        tmp.isNegative ? Duration() : tmp,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      (processing == ProcessingState.loading ||
                                              processing ==
                                                  ProcessingState.buffering)
                                          ? Icons.pending_outlined
                                          : processing ==
                                                  ProcessingState.completed ||
                                              player.position == state?.total
                                          ? Icons.restart_alt
                                          : (isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow),
                                    ),
                                    iconSize: 40,
                                    onPressed: () async {
                                      if (processing ==
                                          ProcessingState.completed) {
                                        await player.seek(Duration());
                                        player.play();
                                      } else {
                                        if (isPlaying) {
                                          await player.pause();
                                        } else {
                                          await player.play();
                                        }
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.forward_10),
                                    iconSize: 30,
                                    onPressed: () async {
                                      Duration tmp =
                                          player.position +
                                          const Duration(seconds: 10);
                                      await player.seek(
                                        tmp > state!.total ? state.total : tmp,
                                      );
                                    },
                                  ),
                                  SizedBox(width: 24),
                                  IconButton(
                                    onPressed: () async {
                                      if (await canLaunchUrlString(
                                        widget.url,
                                      )) {
                                        await launchUrlString(
                                          widget.url,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.open_in_browser_outlined,
                                    ),
                                    iconSize: 30,
                                  ),
                                ],
                              );
                            },
                          ),
                          Text(formatDuration(total)),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
  }
}
