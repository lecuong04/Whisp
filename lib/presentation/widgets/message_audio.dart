import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:waveform_recorder/waveform_recorder.dart';
import 'package:whisp/presentation/widgets/audio_player_modal.dart';

class MessageAudio extends StatefulWidget {
  final double inputHeight;
  final Function() onDeleteAudio;
  final Function(File, String) onMediaSelected;

  const MessageAudio({
    super.key,
    required this.inputHeight,
    required this.onDeleteAudio,
    required this.onMediaSelected,
  });

  @override
  State<StatefulWidget> createState() => _MessageAudioState();
}

class _MessageAudioState extends State<MessageAudio> {
  final AudioPlayer audioPlayer = AudioPlayer();

  WaveformRecorderController waveController = WaveformRecorderController(
    interval: Duration(milliseconds: 100),
    config: RecordConfig(encoder: AudioEncoder.wav),
  );
  bool isLoaded = false;

  String? audioPath;

  void setupRecorderAndAudio() async {
    await waveController.startRecording();
    if (waveController.isRecording) {
      setState(() {
        isLoaded = true;
      });
    } else {
      widget.onDeleteAudio();
    }
  }

  @override
  void initState() {
    super.initState();
    setupRecorderAndAudio();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: isLoaded
          ? Row(
              spacing: 8,
              children: [
                if (waveController.isRecording) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.stop,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onTap: () async {
                      await waveController.stopRecording();
                      setState(() {});
                      await audioPlayer.setReleaseMode(ReleaseMode.stop);
                      await audioPlayer.setSourceDeviceFile(audioPath!);
                      await audioPlayer.pause();
                      setState(() {});
                    },
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: WaveformRecorder(
                        height: 48,
                        controller: waveController,
                        waveColor: Colors.cyan,
                        onRecordingStopped: () {
                          audioPath = waveController.file?.path;
                        },
                      ),
                    ),
                  ),
                ] else ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onTap: () async {
                      File(audioPath!).deleteSync();
                      widget.onDeleteAudio();
                    },
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async => await showModalBottomSheet(
                        context: context,
                        builder: (context) => AudioPlayerModal(path: audioPath),
                      ),
                      label: Text(
                        "Nghe lại",
                        style: TextStyle(fontSize: 18, color: Colors.blue),
                      ),
                      icon: Icon(
                        Icons.play_arrow,
                        size: 32,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      var f = File(audioPath!);
                      await widget.onMediaSelected(File(audioPath!), 'audio');
                      f.deleteSync();
                      widget.onDeleteAudio();
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ],
            )
          : SizedBox(height: widget.inputHeight),
    );
  }
}
