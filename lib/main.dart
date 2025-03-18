import 'dart:typed_data';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:screenshot/screenshot.dart';
import 'package:video_analyzer/analyze_image.dart';
import 'package:video_analyzer/analyze_viewer.dart';
import 'package:video_analyzer/analyzer_controller.dart';
import 'package:video_analyzer/video_analyzer_model.dart';
import 'package:video_player/video_player.dart';

Logger logger = Logger();
void main() {
  runApp(MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(debugShowCheckedModeBanner: false, home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final VideoAnalyzerController analyzerController = Get.put(
    VideoAnalyzerController(),
  );
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Home")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Get.to(VideoAnalyzer());
              },
              child: Text("Analyze Video"),
            ),
            ElevatedButton(
              onPressed: () {},
              child: Text("View Analyzed Video"),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoAnalyzer extends StatefulWidget {
  const VideoAnalyzer({super.key});

  @override
  State<VideoAnalyzer> createState() => _VideoAnalyzerState();
}

class _VideoAnalyzerState extends State<VideoAnalyzer> {
  final String videoURL =
      "https://videos.pexels.com/video-files/4434242/4434242-uhd_1440_2560_24fps.mp4";

  Rx<ChewieController?> playerController = Rx<ChewieController?>(null);
  final ScreenshotController screenshotController = ScreenshotController();
  VideoPlayerController? videoPlayerController;
  PainterController controller = PainterController();
  final VideoAnalyzerController analyzerController = Get.find();
  @override
  void initState() {
    initializePlayer();
    super.initState();
  }

  Future<void> initializePlayer() async {
    videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(videoURL),
    );
    await videoPlayerController!.initialize();

    videoPlayerController!.play();

    playerController.value = ChewieController(
      videoPlayerController: videoPlayerController!,
      aspectRatio: videoPlayerController!.value.aspectRatio,
    );
  }

  final RxBool isPlaying = RxBool(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.indigoAccent, actions: [

      ],),
      body: Obx(
        () =>
            playerController.value == null
                ? Center(child: CircularProgressIndicator())
                : Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: AspectRatio(
                        aspectRatio: playerController.value!.aspectRatio!,
                        child: Screenshot(
                          controller: screenshotController,
                          child: VideoPlayer(videoPlayerController!),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await videoPlayerController?.pause();
          Uint8List? list = await screenshotController.capture();
          if (list == null) {
            return;
          }
          controller.background =
              (await MemoryImage(list).image).backgroundDrawable;

          Get.to(
            () => AnalyzeImage(
              imageData: list,
              aspectRatio: videoPlayerController!.value.aspectRatio,
              timeStamp: videoPlayerController!.value.position.inMilliseconds,
            ),
          );
        },
        label: Text("Analyze"),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            // height: 100,
            color: Colors.white,
            padding: EdgeInsets.all(24),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (c) => VideoAnalyserSheet(),
                    );
                  },
                  child: Text("View analysis"),
                ),
                Spacer(),
                Expanded(
                  child: Row(
                    spacing: 12,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(
                        () => IconButton(
                          onPressed: () {
                            if (videoPlayerController!.value.isPlaying) {
                              isPlaying.value = false;
                              videoPlayerController?.pause();
                              return;
                            }
                            isPlaying.value = true;

                            videoPlayerController?.play();
                          },
                          icon:
                              isPlaying.value
                                  ? Icon(Icons.pause, size: 45)
                                  : Icon(Icons.play_arrow, size: 45),
                        ),
                      ),

                      PopupMenuButton(
                        itemBuilder:
                            (context) => [
                              PopupMenuItem(
                                child: Text("0.2x"),
                                onTap: () {
                                  videoPlayerController?.setPlaybackSpeed(0.25);
                                },
                              ),
                              PopupMenuItem(
                                child: Text("0.5x"),
                                onTap: () {
                                  videoPlayerController?.setPlaybackSpeed(0.5);
                                },
                              ),
                              PopupMenuItem(
                                child: Text("1x"),
                                onTap: () {
                                  videoPlayerController?.setPlaybackSpeed(1);
                                },
                              ),
                              PopupMenuItem(
                                child: Text("1.5x"),
                                onTap: () {
                                  videoPlayerController?.setPlaybackSpeed(1.5);
                                },
                              ),
                              PopupMenuItem(
                                child: Text("2x"),
                                onTap: () {
                                  videoPlayerController?.setPlaybackSpeed(2);
                                },
                              ),
                            ],

                        child: Icon(Icons.speed, size: 40),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String formatTime(int milliseconds) {
    Duration duration = Duration(milliseconds: milliseconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));

    return "$hours:$minutes:$seconds";
  }
}

class VideoAnalyserSheet extends StatefulWidget {
  const VideoAnalyserSheet({super.key});

  @override
  State<VideoAnalyserSheet> createState() => _VideoAnalyserSheetState();
}

class _VideoAnalyserSheetState extends State<VideoAnalyserSheet> {
  final VideoAnalyzerController analyzerController = Get.find();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      width: double.infinity,
      child: Column(
        children: [
          Text(
            "Video Analysis",
            style: Theme.of(context).textTheme.titleMedium,
          ),

          Expanded(
            child: ListView.builder(
              itemCount: analyzerController.analyzerList.length,
              padding: EdgeInsets.zero,
              itemBuilder: (_, index) {
                final VideoAnalyzerModel analyzerModel =
                    analyzerController.analyzerList[index];
                return ListTile(
                  onTap: () {
                    Get.to(() => AnalyzeViewer(analyzerModel: analyzerModel));
                  },
                  title: Text("${analyzerModel.text}"),
                  subtitle: Text(formatTime(analyzerModel.timestamp)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String formatTime(int milliseconds) {
    Duration duration = Duration(milliseconds: milliseconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));

    return "$hours:$minutes:$seconds";
  }
}
