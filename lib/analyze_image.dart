import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_analyzer/analyzer_controller.dart';
import 'package:video_analyzer/audio_recorder_screen.dart';
import 'package:video_analyzer/video_analyzer_model.dart';

import 'main.dart';

class AnalyzeImage extends StatefulWidget {
  final Uint8List imageData;
  final double aspectRatio;
  final int timeStamp;

  const AnalyzeImage({
    super.key,
    required this.imageData,
    required this.aspectRatio,
    required this.timeStamp,
  });

  @override
  State<AnalyzeImage> createState() => _AnalyzeImageState();
}

class _AnalyzeImageState extends State<AnalyzeImage> {
  PainterController? _controller;
  bool _isLoading = true;
  Color _currentColor = Colors.black;
  FreeStyleMode _currentMode = FreeStyleMode.none;
  final double _scale = 1.0;
  final TransformationController _transformationController =
      TransformationController();
  String? _selectedTool; // Track the selected tool (null means none selected)

  bool isRecording = false;

  late FlutterSoundRecorder _audioRecorder; // For saving audio
  StreamSubscription<List<int>>? _audioStreamSubscription;
  final List<double> _waveformData = []; // Store amplitude data for waveform
  final bool _isRecording = false;
  String? _audioPath;

  final VideoAnalyzerController analyzerController = Get.find();
  @override
  void initState() {
    super.initState();
    _audioRecorder = FlutterSoundRecorder();

    initPainter();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _audioRecorder.openRecorder();
  }

  Future<void> initPainter() async {
    try {
      final ui.Image decodedImage = await decodeImageFromList(widget.imageData);
      _controller = PainterController(
        settings: PainterSettings(
          freeStyle: FreeStyleSettings(
            mode: FreeStyleMode.none,
            color: _currentColor,
            strokeWidth: 5,
          ),
          shape: ShapeSettings(
            paint:
                Paint()
                  ..color = _currentColor
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 5,
          ),
          text: TextSettings(
            textStyle: TextStyle(color: _currentColor, fontSize: 16),
          ),
        ),
      )..background = ImageBackgroundDrawable(image: decodedImage);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      logger.e("Error initializing painter: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Show color picker dialog
  void _showColorPicker() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Pick a color'),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: _currentColor,
                onColorChanged: (color) {
                  setState(() {
                    _currentColor = color;
                    _controller!.freeStyleSettings = FreeStyleSettings(
                      mode: _currentMode,
                      color: color,
                      strokeWidth: 5,
                    );
                    _controller!.shapeSettings = ShapeSettings(
                      paint:
                          Paint()
                            ..color = color
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 5,
                    );
                    _controller!.textSettings = TextSettings(
                      textStyle: TextStyle(color: color, fontSize: 16),
                    );
                  });
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
    );
  }

  // Export the drawing as an image
  String audioPath = "";
  Future<void> saveAnalysis() async {
    if (_controller == null) return;

    Get.dialog(
      AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Saving analysis..."),
          ],
        ),
      ),
    );
    try {
      final renderedImage = await _controller!.renderImage(
        Size(widget.aspectRatio * 5000, 5000),
      );
      final byteData = await renderedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw Exception("Failed to convert image to byte data");
      }
      final pngBytes = byteData.buffer.asUint8List();

      final Directory docDirectory = await getApplicationDocumentsDirectory();

      String imagePath =
          "${docDirectory.path}/${DateTime.now().millisecondsSinceEpoch}-analysis.png";

      File imageFile = File(imagePath);

      if ((await imageFile.exists()) == false) {
        imageFile = await imageFile.create();
      }
      imageFile = await imageFile.writeAsBytes(pngBytes);

      analyzerController.analyzerList.add(
        VideoAnalyzerModel(
          imagePath: imagePath,
          timestamp: widget.timeStamp,
          text: textEditingController.text,
          audioPath: audioPath,
        ),
      );
      Get.back();
      Get.back();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to export image: $e")));
    }
  }

  final TextEditingController textEditingController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analyze"),
        actions: [
          // IconButton(icon: const Icon(Icons.zoom_in), onPressed: _zoomIn),
          // IconButton(icon: const Icon(Icons.zoom_out), onPressed: _zoomOut),
        ],

        bottom: PreferredSize(
          preferredSize: Size(double.infinity, 75),
          child: Column(
            children: [
              Container(
                color: Colors.blue.shade100,
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Color Picker
                    IconButton(
                      onPressed: _showColorPicker,
                      icon: Icon(Icons.color_lens, color: _currentColor),
                    ),
                    // Free Drawing
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _currentMode =
                              _currentMode == FreeStyleMode.draw
                                  ? FreeStyleMode.none
                                  : FreeStyleMode.draw;
                          _selectedTool =
                              _currentMode == FreeStyleMode.draw
                                  ? 'brush'
                                  : null;
                          _controller!.freeStyleSettings = FreeStyleSettings(
                            mode: _currentMode,
                            color: _currentColor,
                            strokeWidth: 5,
                          );
                          _controller!.shapeSettings = const ShapeSettings();
                        });
                      },
                      icon: Icon(
                        Icons.brush,
                        color: _selectedTool == 'brush' ? Colors.blue : null,
                      ),
                    ),
                    // Circle
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _currentMode = FreeStyleMode.none;
                          _selectedTool = 'circle';
                          _controller!.freeStyleSettings =
                              const FreeStyleSettings(mode: FreeStyleMode.none);
                          _controller!.shapeSettings = ShapeSettings(
                            paint:
                                Paint()
                                  ..color = _currentColor
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = 5,
                            factory: OvalFactory(),
                          );
                        });
                      },
                      icon: Icon(
                        Icons.circle_outlined,
                        color: _selectedTool == 'circle' ? Colors.blue : null,
                      ),
                    ),
                    // Rectangle
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _currentMode = FreeStyleMode.none;
                          _selectedTool = 'rectangle';
                          _controller!.freeStyleSettings =
                              const FreeStyleSettings(mode: FreeStyleMode.none);
                          _controller!.shapeSettings = ShapeSettings(
                            paint:
                                Paint()
                                  ..color = _currentColor
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = 5,
                            factory: RectangleFactory(),
                          );
                        });
                      },
                      icon: Icon(
                        Icons.rectangle_outlined,
                        color:
                            _selectedTool == 'rectangle' ? Colors.blue : null,
                      ),
                    ),
                    // Arrow
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _currentMode = FreeStyleMode.none;
                          _selectedTool = 'arrow';
                          _controller!.freeStyleSettings =
                              const FreeStyleSettings(mode: FreeStyleMode.none);
                          _controller!.shapeSettings = ShapeSettings(
                            paint:
                                Paint()
                                  ..color = _currentColor
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = 5,
                            factory: ArrowFactory(),
                          );
                        });
                      },
                      icon: Icon(
                        Icons.arrow_right_alt,
                        color: _selectedTool == 'arrow' ? Colors.blue : null,
                      ),
                    ),
                    // Text
                    // IconButton(
                    //   onPressed: () {
                    //     setState(() {
                    //       _selectedTool = 'text';
                    //       _controller!.freeStyleSettings = const FreeStyleSettings(
                    //         mode: FreeStyleMode.none,
                    //       );
                    //       _controller!.shapeSettings = const ShapeSettings();
                    //       _controller!.textSettings = TextSettings(
                    //         textStyle: TextStyle(
                    //           color: _currentColor,
                    //           fontSize: 16,
                    //         ),
                    //       );
                    //       _controller!.addText();
                    //     });
                    //   },
                    //   icon: Icon(
                    //     Icons.text_fields,
                    //     color: _selectedTool == 'text' ? Colors.blue : null,
                    //   ),
                    // ),
                    // Delete
                    IconButton(
                      onPressed: () {
                        if (_controller!.drawables.isNotEmpty) {
                          _controller!.removeDrawable(
                            _controller!.drawables.last,
                          );
                        }
                      },
                      icon: const Icon(Icons.delete),
                    ),
                    // Export
                    IconButton(
                      onPressed: saveAnalysis,
                      icon: const Icon(Icons.save),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
            ],
          ),
        ),
      ),
      body: InteractiveViewer(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _controller == null
                ? const Center(child: Text("Error loading image"))
                : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        // physics: NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          width: double.infinity,
                          height:
                              Get.height -
                              (MediaQuery.of(context).padding.top +
                                  MediaQuery.of(context).padding.bottom +
                                  130 +
                                  110),
                          child: AspectRatio(
                            aspectRatio: widget.aspectRatio,
                            child: FlutterPainter(controller: _controller!),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(24),
                      child: Row(
                        spacing: 12,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(36),
                              child: TextField(
                                // onTap: () {
                                //   Get.bottomSheet(
                                //     Container(
                                //       padding: EdgeInsets.all(24),
                                //       color:
                                //           Theme.of(
                                //             context,
                                //           ).scaffoldBackgroundColor,
                                //       child: Column(
                                //         spacing: 24,
                                //         mainAxisSize: MainAxisSize.min,
                                //         children: [
                                //           TextField(
                                //             controller: textEditingController,
                                //             decoration: InputDecoration(
                                //               border: InputBorder.none,
                                //               filled: true,
                                //               contentPadding: EdgeInsets.all(12),
                                //               hintText: 'Type your input',
                                //             ),
                                //           ),

                                //           ElevatedButton(
                                //             onPressed: () {
                                //               Get.back();
                                //             },
                                //             child: Text("Save"),
                                //           ),
                                //         ],
                                //       ),
                                //     ),
                                //   );
                                // },
                                // readOnly: true,
                                controller: textEditingController,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  filled: true,
                                  contentPadding: EdgeInsets.all(12),
                                  hintText: 'Type your input',
                                ),
                              ),
                            ),
                          ),

                          IconButton(
                            onPressed: () {
                              Get.bottomSheet(
                                AudioRecorderScreen(
                                  onRecordingEnded: (String path) {
                                    audioPath = path;
                                    Get.back();
                                  },
                                ),
                              );
                            },
                            icon: Icon(Icons.mic),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),

      // bottomNavigationBar: Column(
      //   mainAxisSize: MainAxisSize.min,
      //   children: [
      //     Divider(),
      //     Container(
      //       padding: EdgeInsets.all(16),
      //       // height: 150,
      //       child: Row(
      //         spacing: 12,
      //         children: [
      //           Expanded(
      //             child: ClipRRect(
      //               borderRadius: BorderRadius.circular(36),
      //               child: TextField(
      //                 onTap: () {
      //                   Get.bottomSheet(
      //                     Container(
      //                       padding: EdgeInsets.all(24),
      //                       color: Theme.of(context).scaffoldBackgroundColor,
      //                       child: Column(
      //                         spacing: 24,
      //                         mainAxisSize: MainAxisSize.min,
      //                         children: [
      //                           TextField(
      //                             controller: textEditingController,
      //                             decoration: InputDecoration(
      //                               border: InputBorder.none,
      //                               filled: true,
      //                               contentPadding: EdgeInsets.all(12),
      //                               hintText: 'Type your input',
      //                             ),
      //                           ),

      //                           ElevatedButton(
      //                             onPressed: () {
      //                               Get.back();
      //                             },
      //                             child: Text("Save"),
      //                           ),
      //                         ],
      //                       ),
      //                     ),
      //                   );
      //                 },
      //                 readOnly: true,
      //                 controller: textEditingController,
      //                 decoration: InputDecoration(
      //                   border: InputBorder.none,
      //                   filled: true,
      //                   contentPadding: EdgeInsets.all(12),
      //                   hintText: 'Type your input',
      //                 ),
      //               ),
      //             ),
      //           ),

      //           IconButton(
      //             onPressed: () {
      //               if (isRecording == true) {
      //                 isRecording = false;

      //                 return;
      //               }
      //               isRecording = true;
      //             },
      //             icon: Icon(Icons.mic),
      //           ),
      //         ],
      //       ),
      //     ),
      //     SizedBox(height: 16),
      //   ],
      // ),
    );
  }

  Future<void> toggleRecording() async {
    // if (_isRecording) {
    //   await _audioRecorder.stopRecorder();
    //   _audioStreamSubscription?.cancel();
    //   setState(() {
    //     _isRecording = false;
    //     _selectedTool = null;
    //     _audioPath = _audioRecorder; // Use actual path if available
    //     _waveformData.clear();
    //   });
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text("Recording saved to: $_audioPath")),
    //   );
    // } else {
    //   if (await _audioRecorder.isMicrophonePermissionGranted()) {
    //     final directory = await getTemporaryDirectory();
    //     final filePath =
    //         '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.aac';
    //     await _audioRecorder.startRecorder(
    //       toFile: filePath,
    //       codec: Codec.aacMP4,
    //     );

    //     _audioStreamSubscription = _audioRecorder.onProgress!.listen((event) {
    //       final samples =
    //           event.decibels; // Use decibels or PCM data if available
    //       double amplitude = samples != null ? samples / 100 : 0.0; // Normalize
    //       setState(() {
    //         _waveformData.add(amplitude);
    //         if (_waveformData.length > 50) _waveformData.removeAt(0);
    //       });
    //     });

    //     setState(() {
    //       _isRecording = true;
    //       _selectedTool = 'mic';
    //     });
    //   } else {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(content: Text("Microphone permission denied")),
    //     );
    //   }
    // }
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;

  WaveformPainter(this.waveformData);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0;

    if (waveformData.isEmpty) return;

    final double widthPerSample = size.width / waveformData.length;
    final double halfHeight = size.height / 2;

    for (int i = 0; i < waveformData.length - 1; i++) {
      final x1 = i * widthPerSample;
      final y1 = halfHeight - (waveformData[i] * halfHeight);
      final x2 = (i + 1) * widthPerSample;
      final y2 = halfHeight - (waveformData[i + 1] * halfHeight);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
