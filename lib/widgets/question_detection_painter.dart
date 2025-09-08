/*import 'package:flutter/material.dart';

class DetectedQuestion {
  final double confidence;
  final double boundingBox;
  final double questionNumber;
  final int detectedAnswer;

  const DetectedQuestion({
    required this.confidence,
    required this.boundingBox,
    required this.questionNumber,
    required this.detectedAnswer,

  });
}

class QuestionDetectionPainter extends CustomPainter {
  final List<DetectedQuestion> detectedQuestions;
  final bool isDetecting;
  final Animation<double> detectionAnimation;
  final Rect? paperBounds;
  final bool paperDetected;
  final double paperConfidence;

  QuestionDetectionPainter({
    required this.detectedQuestions,
    required this.isDetecting,
    required this.detectionAnimation,
    this.paperBounds,
    required this.paperDetected,
    required this.paperConfidence,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Desenhar detecção do papel primeiro
    if (paperBounds != null) {
      _drawPaperDetection(canvas, size);
    }

    // Desenhar grid de auxílio se papel detectado
    if (paperDetected && paperBounds != null) {
      _drawAlignmentGrid(canvas, size);
    }

    // Desenhar detecções de questões
    _drawQuestionDetections(canvas, size);
  }

  void _drawPaperDetection(Canvas canvas, Size size) {
    if (paperBounds == null) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fillPaint = Paint()..style = PaintingStyle.fill;

    // Cor baseada na confiança de detecção do papel
    final Color paperColor = paperDetected
        ? Colors.green.withValues(alpha: 0.8)
        : Colors.orange.withValues(alpha: 0.6);

    paint.color = paperColor;
    fillPaint.color = paperColor.withValues(alpha: 0.1);

    // Desenhar contorno do papel
    final paperRect = RRect.fromRectAndRadius(
      paperBounds!,
      const Radius.circular(12),
    );

    canvas.drawRRect(paperRect, fillPaint);
    canvas.drawRRect(paperRect, paint);

    // Desenhar indicador de confiança
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final confidenceText = paperDetected
        ? 'PAPEL DETECTADO'
        : 'DETECTANDO PAPEL...';

    textPainter.text = TextSpan(
      text: confidenceText,
      style: TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 4,
          ),
        ],
      ),
    );
    textPainter.layout();

    final labelRect = Rect.fromLTWH(
      paperBounds!.left,
      paperBounds!.top - 35,
      textPainter.width + 16,
      25,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(12)),
      Paint()..color = paperColor,
    );

    textPainter.paint(
      canvas,
      Offset(paperBounds!.left + 8, paperBounds!.top - 32),
    );

    // Barra de confiança
    final confidenceBarWidth = 100.0;
    final confidenceBarHeight = 6.0;
    final confidenceBarRect = Rect.fromLTWH(
      paperBounds!.right - confidenceBarWidth - 8,
      paperBounds!.top - 30,
      confidenceBarWidth,
      confidenceBarHeight,
    );

    // Background da barra
    canvas.drawRRect(
      RRect.fromRectAndRadius(confidenceBarRect, const Radius.circular(3)),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );

    // Preenchimento da barra baseado na confiança
    final filledWidth = confidenceBarWidth * paperConfidence;
    final filledRect = Rect.fromLTWH(
      confidenceBarRect.left,
      confidenceBarRect.top,
      filledWidth,
      confidenceBarHeight,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(filledRect, const Radius.circular(3)),
      Paint()..color = paperColor,
    );
  }

  void _drawAlignmentGrid(Canvas canvas, Size size) {
    if (paperBounds == null) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.3);

    // Desenhar linhas de grade para auxiliar no alinhamento
    final gridSpacing = 40.0;

    // Linhas verticais
    for (
      double x = paperBounds!.left;
      x <= paperBounds!.right;
      x += gridSpacing
    ) {
      canvas.drawLine(
        Offset(x, paperBounds!.top),
        Offset(x, paperBounds!.bottom),
        paint,
      );
    }

    // Linhas horizontais
    for (
      double y = paperBounds!.top;
      y <= paperBounds!.bottom;
      y += gridSpacing
    ) {
      canvas.drawLine(
        Offset(paperBounds!.left, y),
        Offset(paperBounds!.right, y),
        paint,
      );
    }
  }

  void _drawQuestionDetections(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPaint = Paint()..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < detectedQuestions.length; i++) {
      final question = detectedQuestions[i];
      final animationProgress = (i < detectedQuestions.length - 1)
          ? 1.0
          : detectionAnimation.value;

      // Cor baseada na confiança
      final confidence = question.confidence;
      final color = Color.lerp(
        Colors.red,
        Colors.green,
        confidence,
      )!.withValues(alpha: 0.9 * animationProgress);

      paint.color = color;
      fillPaint.color = color.withValues(alpha: 0.2 * animationProgress);

      // Desenha o retângulo de detecção com animação pulsante
      final pulseScale = 1.0 + (0.1 * animationProgress);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: question.boundingBox.center,
          width: question.boundingBox.width * pulseScale,
          height: question.boundingBox.height * pulseScale,
        ),
        const Radius.circular(8),
      );

      canvas.drawRRect(rect, fillPaint);
      canvas.drawRRect(rect, paint);

      // Desenha o número da questão
      textPainter.text = TextSpan(
        text: 'Q${question.questionNumber}',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 2,
            ),
          ],
        ),
      );
      textPainter.layout();

      final labelRect = Rect.fromLTWH(
        question.boundingBox.left - 5,
        question.boundingBox.top - 22,
        textPainter.width + 10,
        18,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(9)),
        Paint()..color = color,
      );

      textPainter.paint(
        canvas,
        Offset(question.boundingBox.left, question.boundingBox.top - 19),
      );

      // Desenha a resposta detectada se houver
      if (question.detectedAnswer != null) {
        textPainter.text = TextSpan();
      }
    }
  }

  @override
  bool shouldRepaint(covariant QuestionDetectionPainter oldDelegate) {
    return detectedQuestions != oldDelegate.detectedQuestions ||
        isDetecting != oldDelegate.isDetecting ||
        detectionAnimation != oldDelegate.detectionAnimation;
  }
}*/
