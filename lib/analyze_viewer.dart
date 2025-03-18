import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_analyzer/main.dart';
import 'package:video_analyzer/video_analyzer_model.dart';

class AnalyzeViewer extends StatefulWidget {
  final VideoAnalyzerModel analyzerModel;
  const AnalyzeViewer({super.key, required this.analyzerModel});

  @override
  State<AnalyzeViewer> createState() => _AnalyzeViewerState();
}

class _AnalyzeViewerState extends State<AnalyzeViewer> {
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

      bottomNavigationBar: Container(height: 150),
    );
  }
}
