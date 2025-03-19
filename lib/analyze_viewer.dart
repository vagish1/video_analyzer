import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:video_analyzer/main.dart';
import 'package:video_analyzer/video_analyzer_model.dart';

class AnalyzeViewer extends StatefulWidget {
  final VideoAnalyzerModel analyzerModel;
  const AnalyzeViewer({super.key, required this.analyzerModel});

  @override
  State<AnalyzeViewer> createState() => _AnalyzeViewerState();
}

class _AnalyzeViewerState extends State<AnalyzeViewer> {
  FlutterSoundPlayer flutterSoundPlayer = FlutterSoundPlayer();

  @override
  void initState() {
    initPlayer();
    super.initState();
  }

  bool _isPlaying = false;

  Future<void> initPlayer() async {
    await flutterSoundPlayer.openPlayer();
    await flutterSoundPlayer.startPlayer(
      fromURI: widget.analyzerModel.audioPath,
      whenFinished: () {
        setState(() => _isPlaying = false);
      },
    );
    await flutterSoundPlayer.pausePlayer();
  }

  @override
  void dispose() {
    flutterSoundPlayer.stopPlayer();
    flutterSoundPlayer.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    logger.d(widget.analyzerModel.toString());
    return Scaffold(
      appBar: AppBar(title: Text("Analysis")),
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: Image.file(File(widget.analyzerModel.imagePath)),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.analyzerModel.text ?? "",
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: SizedBox(
        height: 150,
        child: IconButton(
          onPressed: () {
            if (_isPlaying) {
              _isPlaying = false;
              flutterSoundPlayer.pausePlayer();
              setState(() {});
              return;
            }
            flutterSoundPlayer.resumePlayer();
            _isPlaying = true;
            setState(() {});
          },
          icon:
              _isPlaying
                  ? Icon(Icons.pause, size: 60)
                  : Icon(Icons.play_arrow, size: 60),
        ),
      ),
    );
  }
}
