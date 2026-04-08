import 'dart:ui' show Rect;

class StaticDetectedBubble {
  final Rect rect;
  final bool isMarked;
  StaticDetectedBubble({required this.rect, required this.isMarked});
}

class ProcessedSheetResult {
  final List<String?> answers;
  final List<StaticDetectedBubble> bubbles;
  final double imageWidth;
  final double imageHeight;

  ProcessedSheetResult({
    required this.answers,
    required this.bubbles,
    required this.imageWidth,
    required this.imageHeight,
  });
}
