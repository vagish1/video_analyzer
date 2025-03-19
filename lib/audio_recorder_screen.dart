import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderScreen extends StatefulWidget {
  final Function(String) onRecordingEnded;
  const AudioRecorderScreen({super.key, required this.onRecordingEnded});

  @override
  _AudioRecorderScreenState createState() => _AudioRecorderScreenState();
}

class _AudioRecorderScreenState extends State<AudioRecorderScreen> {
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _initRecorder();
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    _recorder = null;
    super.dispose();
  }

  Future<void> _initRecorder() async {
    await _recorder!.openRecorder();

    // Request microphone permission
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
  }

  Future<void> _startRecording() async {
    try {
      Directory tempDir = await getTemporaryDirectory();
      _filePath =
          '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder!.startRecorder(toFile: _filePath, codec: Codec.aacMP4);

      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder!.stopRecorder();
      setState(() {
        _isRecording = false;
      });
      print('Recording saved at: $_filePath');

      widget.onRecordingEnded(_filePath!);
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Audio Recorder')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isRecording ? 'Recording...' : 'Ready to record',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
            if (_filePath != null && !_isRecording)
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Last recording: $_filePath'),
              ),
          ],
        ),
      ),
    );
  }
}
