import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

class AudioRecorderModal extends StatefulWidget {
  const AudioRecorderModal({super.key});

  @override
  State<StatefulWidget> createState() => _AudioRecorderModalState();
}

class _AudioRecorderModalState extends State<AudioRecorderModal> {
  final record = AudioRecorder();
  Stream<Uint8List>? audioStream;
  bool isStopped = false;
  List<int> data = List.empty(growable: true);

  @override
  void initState() {
    super.initState();
    record.onStateChanged().listen((event) {});
  }

  @override
  void dispose() {
    record.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return audioStream == null
        ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                if (await record.hasPermission()) {
                  audioStream = await record.startStream(
                    const RecordConfig(encoder: AudioEncoder.pcm16bits),
                  );
                  audioStream!.listen((event) {
                    data.addAll(event);
                  });
                }
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(),
                padding: EdgeInsets.all(20),
                backgroundColor: Colors.blue,
              ),
              child: Icon(Icons.mic, color: Colors.white, size: 32),
            ),
          ],
        )
        : !isStopped
        ? Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: () async {
                await record.cancel();
                setState(() {
                  audioStream = null;
                  data.clear();
                });
              },
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(),
                padding: EdgeInsets.all(20),
                backgroundColor: Colors.blue,
              ),
              child: Icon(Icons.delete, color: Colors.white, size: 32),
            ),
            ElevatedButton(
              onPressed: () async {
                await record.stop();
                setState(() {
                  isStopped = true;
                });
              },
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(),
                padding: EdgeInsets.all(20),
                backgroundColor: Colors.blue,
              ),
              child: Icon(Icons.stop, color: Colors.white, size: 32),
            ),
          ],
        )
        : Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isStopped = false;
                  data.clear();
                  audioStream = null;
                });
              },
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(),
                padding: EdgeInsets.all(20),
                backgroundColor: Colors.blue,
              ),
              child: Icon(Icons.restart_alt, color: Colors.white, size: 32),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, Uint8List.fromList(data));
              },
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(),
                padding: EdgeInsets.all(20),
                backgroundColor: Colors.blue,
              ),
              child: Icon(Icons.send, color: Colors.white, size: 32),
            ),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(),
                padding: EdgeInsets.all(20),
                backgroundColor: Colors.blue,
              ),
              child: Icon(Icons.play_arrow, color: Colors.white, size: 32),
            ),
          ],
        );
  }
}
