import 'package:flutter/material.dart';

import '../models/static_detected_bubble.dart';

class StaticBubbleOverlayPainter extends CustomPainter {
  final List<StaticDetectedBubble> bubbles;

  final Paint _markedFill = Paint()
    ..color = Colors.green.withValues(alpha: 0.4)
    ..style = PaintingStyle.fill;

  final Paint _markedStroke = Paint()
    ..color = Colors.green
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  final Paint _unmarkedStroke = Paint()
    ..color = Colors.blue.withValues(alpha: 0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  StaticBubbleOverlayPainter({required this.bubbles});

  @override
  void paint(Canvas canvas, Size size) {
    if (bubbles.isEmpty) return;

    for (final bubble in bubbles) {
      if (bubble.isMarked) {
        canvas.drawOval(bubble.rect, _markedFill);
        canvas.drawOval(bubble.rect, _markedStroke);
      } else {
        canvas.drawOval(bubble.rect, _unmarkedStroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StaticBubbleOverlayPainter oldDelegate) {
    return oldDelegate.bubbles != bubbles;
  }
}
