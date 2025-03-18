class VideoAnalyzerModel {
  final String imagePath;
  final int timestamp;
  String? audioPath;
  String? text;

  VideoAnalyzerModel({
    required this.imagePath,
    this.audioPath,
    this.text,
    required this.timestamp,
  });

  @override
  String toString() {
    // TODO: implement toString
    return "text: $text";
  }
}
