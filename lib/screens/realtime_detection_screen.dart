import 'dart:io';
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../models/exam.dart';
import '../utils/input_image.dart';
import '../utils/utils.dart';

class RealtimeDetectionScreen extends StatefulWidget {
  final CameraDescription camera;
  final Exam exam;

  const RealtimeDetectionScreen({
    super.key,
    required this.camera,
    required this.exam,
  });

  @override
  State<RealtimeDetectionScreen> createState() =>
      _RealtimeDetectionScreenState();
}

class _RealtimeDetectionScreenState extends State<RealtimeDetectionScreen>
    with WidgetsBindingObserver {
  late CameraController _cameraController;
  bool _isProcessing = false;
  bool _isDetectionActive = true;
  List<String?>? _detectedAnswers;
  List<DetectedBubble> _detectedBubbles = [];

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();
  double _fps = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopDetection();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopDetection();
      _cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      // Define o formato de imagem de forma inteligente baseado na plataforma
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController.initialize();
      if (mounted) {
        setState(() {});
        _startDetection();
      }
    } catch (e) {
      _showError('Erro ao inicializar câmera: $e');
    }
  }

  void _toggleDetection() {
    setState(() {
      if (_isDetectionActive) {
        _stopDetection();
      } else {
        _startDetection();
      }
    });
  }

  void _startDetection() {
    if (!_cameraController.value.isInitialized || _isDetectionActive) return;

    _isDetectionActive = true;
    _cameraController.startImageStream(_processCameraImage);
    if (mounted) setState(() {});
  }

  void _stopDetection() {
    if (!_isDetectionActive) return;

    _isDetectionActive = false;
    _cameraController.stopImageStream().catchError((e) {
      print('Erro ao parar stream: $e');
    });
    if (mounted) setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;

    _isProcessing = true;
    if (mounted) setState(() {});

    try {
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) {
        print('Formato de imagem não suportado: ${image.format.group}');
        return;
      }

      // Converte a imagem da câmera para bytes no formato RGBA
      final bytes = switch (format) {
        InputImageFormat.yuv_420_888 => yuv420ToRGBA8888(image),
        InputImageFormat.bgra8888 => bgraToRgbaInPlace(
          image.planes.first.bytes,
        ),
        _ => null, // Suporta yuv e bgra por enquanto
      };

      if (bytes == null) {
        print('Falha ao converter a imagem.');
        return;
      }

      // Cria a matriz do OpenCV a partir dos bytes
      cv.Mat mat = cv.Mat.fromList(
        image.height,
        image.width,
        cv.MatType.CV_8UC4, // 4 canais (RGBA)
        bytes,
      );

      // Converte de RGBA para BGR, o formato que o OpenCV usa internamente
      mat = cv.cvtColor(mat, cv.COLOR_RGBA2BGR);

      // ** LÓGICA CRÍTICA DE ROTAÇÃO DA IMAGEM **
      final sensorOrientation = widget.camera.sensorOrientation;
      var rotationCompensation =
          _orientations[_cameraController.value.deviceOrientation];
      if (rotationCompensation != null) {
        if (widget.camera.lensDirection == CameraLensDirection.front) {
          rotationCompensation =
              (sensorOrientation + rotationCompensation) % 360;
        } else {
          rotationCompensation =
              (sensorOrientation - rotationCompensation + 360) % 360;
        }

        // Aplica a rotação necessária na matriz
        switch (rotationCompensation) {
          case 90:
            mat = cv.rotate(mat, cv.ROTATE_90_CLOCKWISE);
            break;
          case 180:
            mat = cv.rotate(mat, cv.ROTATE_180);
            break;
          case 270:
            mat = cv.rotate(mat, cv.ROTATE_90_COUNTERCLOCKWISE);
            break;
        }
      }

      // Chama a sua função de detecção original com a imagem já corrigida
      final result = await _detectBubblesRealtime(mat);

      if (mounted) {
        setState(() {
          _detectedBubbles = result.bubbles;
          _detectedAnswers = result.answers;
        });
      }

      _updateFps();
    } catch (e) {
      print('Erro ao processar frame: $e');
    } finally {
      _isProcessing = false;
      if (mounted) setState(() {});
    }
  }

  void _updateFps() {
    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastFpsUpdate).inMilliseconds;

    if (elapsed >= 1000) {
      if (mounted) {
        setState(() {
          _fps = _frameCount * 1000 / elapsed;
        });
      }
      _frameCount = 0;
      _lastFpsUpdate = now;
    }
  }

  // O resto do seu código (lógica de detecção e UI) permanece praticamente o mesmo,
  // pois a lógica principal de detecção já era muito boa.

  Future<DetectionResult> _detectBubblesRealtime(cv.Mat image) async {
    try {
      final originalSize = (image.width, image.height);
      final processingSize = (480, 640);

      final resized = cv.resize(
        image,
        processingSize,
        interpolation: cv.INTER_AREA,
      );
      final gray = cv.cvtColor(resized, cv.COLOR_BGR2GRAY);
      final blurred = cv.gaussianBlur(gray, (5, 5), 0);
      final thresh = cv.adaptiveThreshold(
        blurred,
        255,
        cv.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv.THRESH_BINARY_INV,
        11,
        2,
      );
      final kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
      final cleaned = cv.morphologyEx(thresh, cv.MORPH_OPEN, kernel);

      final contours = cv
          .findContours(cleaned, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE)
          .$1;

      final bubbles = <DetectedBubble>[];
      final scaleX = originalSize.$1 / processingSize.$1;
      final scaleY = originalSize.$2 / processingSize.$2;

      for (final contour in contours) {
        final rect = cv.boundingRect(contour);
        final aspectRatio = rect.width / rect.height.toDouble();
        final area = cv.contourArea(contour);

        if (area > 150 && aspectRatio >= 0.7 && aspectRatio <= 1.3) {
          final scaledRect = Rect.fromLTWH(
            rect.x * scaleX,
            rect.y * scaleY,
            rect.width * scaleX,
            rect.height * scaleY,
          );

          final mask = cv.Mat.zeros(
            cleaned.rows,
            cleaned.cols,
            cv.MatType.CV_8UC1,
          );
          cv.drawContours(
            mask,
            cv.VecVecPoint.fromVecPoint(contour),
            -1,
            cv.Scalar.all(255),
            thickness: -1,
          );

          final masked = cv.bitwiseAND(cleaned, cleaned, mask: mask);
          final filledPixels = cv.countNonZero(masked);
          final totalPixels = area;
          final fillRatio = totalPixels > 0 ? filledPixels / totalPixels : 0.0;

          bubbles.add(
            DetectedBubble(
              rect: scaledRect,
              fillRatio: fillRatio,
              isMarked: fillRatio > 0.45, // Threshold ajustado
            ),
          );
        }
      }

      final answers = _organizeBubblesIntoAnswers(bubbles);
      return DetectionResult(bubbles: bubbles, answers: answers);
    } catch (e) {
      print('Erro na detecção: $e');
      return DetectionResult(bubbles: [], answers: []);
    }
  }

  List<String?> _organizeBubblesIntoAnswers(List<DetectedBubble> bubbles) {
    if (bubbles.isEmpty) return [];

    final answers = <String?>[];
    final rowTolerance =
        30.0; // Tolerância em pixels para agrupar na mesma linha

    // Ordena bolhas primariamente por Y, depois por X
    bubbles.sort((a, b) {
      if ((a.rect.top - b.rect.top).abs() < rowTolerance) {
        return a.rect.left.compareTo(b.rect.left);
      }
      return a.rect.top.compareTo(b.rect.top);
    });

    final questionRows = <List<DetectedBubble>>[];
    if (bubbles.isNotEmpty) {
      var currentRow = <DetectedBubble>[bubbles.first];
      for (int i = 1; i < bubbles.length; i++) {
        if ((bubbles[i].rect.top - currentRow.first.rect.top).abs() <
            rowTolerance) {
          currentRow.add(bubbles[i]);
        } else {
          questionRows.add(List.from(currentRow));
          currentRow = [bubbles[i]];
        }
      }
      questionRows.add(currentRow);
    }

    // Ordena as linhas por posição Y
    questionRows.sort((a, b) => a.first.rect.top.compareTo(b.first.rect.top));

    for (var row in questionRows) {
      if (row.length == widget.exam.availableOptions.length) {
        row.sort((a, b) => a.rect.left.compareTo(b.rect.left));

        int markedIndex = -1;
        double maxFillRatio = 0.0;

        // Encontra a bolha mais preenchida na linha
        for (int i = 0; i < row.length; i++) {
          if (row[i].isMarked && row[i].fillRatio > maxFillRatio) {
            maxFillRatio = row[i].fillRatio;
            markedIndex = i;
          }
        }

        // Verifica se mais de uma bolha foi marcada (anula a questão)
        final markedCount = row.where((b) => b.isMarked).length;

        if (markedCount == 1 && markedIndex != -1) {
          answers.add(widget.exam.availableOptions[markedIndex]);
        } else {
          answers.add(null); // Questão em branco ou anulada
        }
      }
    }
    return answers;
  }

  void _captureCurrentFrame() {
    if (_detectedAnswers != null && _detectedAnswers!.isNotEmpty) {
      Navigator.of(context).pop(_detectedAnswers);
    } else {
      _showError('Nenhuma resposta detectada para capturar');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_cameraController.value.isInitialized
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              fit: StackFit.expand,
              children: [
                // Para ajustar o preview da câmera corretamente
                Center(
                  child: AspectRatio(
                    aspectRatio: _cameraController.value.aspectRatio,
                    child: CameraPreview(_cameraController),
                  ),
                ),
                // O CustomPaint precisa de um painter que entenda a escala
                CustomPaint(
                  painter: BubbleOverlayPainter(
                    bubbles: _detectedBubbles,
                    previewSize: MediaQuery.of(context).size,
                    cameraSize: Size(
                      _cameraController.value.previewSize!.height,
                      _cameraController.value.previewSize!.width,
                    ),
                  ),
                  size: Size.infinite,
                ),
                // A UI de controle permanece a mesma
                _buildTopUI(context),
                _buildBottomUI(context),
                if (_isProcessing) _buildProcessingIndicator(),
              ],
            ),
    );
  }

  // UI Widgets (extraídos para melhor organização)
  Widget _buildTopUI(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 20,
          right: 20,
          bottom: 10,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detecção em Tempo Real',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'FPS: ${_fps.toStringAsFixed(1)} | Questões: ${widget.exam.numQuestions}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomUI(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isDetectionActive
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: _isDetectionActive ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isDetectionActive
                        ? 'Detectando: ${_detectedAnswers?.where((a) => a != null).length ?? 0}/${widget.exam.numQuestions}'
                        : 'Detecção pausada',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  onPressed: _toggleDetection,
                  backgroundColor: _isDetectionActive
                      ? Colors.red
                      : Colors.green,
                  heroTag: 'detection_toggle',
                  child: Icon(
                    _isDetectionActive ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                FloatingActionButton.extended(
                  onPressed:
                      _detectedAnswers != null &&
                          _detectedAnswers!.any((a) => a != null)
                      ? _captureCurrentFrame
                      : null,
                  backgroundColor:
                      _detectedAnswers != null &&
                          _detectedAnswers!.any((a) => a != null)
                      ? Colors.blue
                      : Colors.grey,
                  heroTag: 'capture',
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text(
                    'Capturar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Positioned(
      top: 100,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Processando...',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// Classes auxiliares
class DetectedBubble {
  final Rect rect;
  final double fillRatio;
  final bool isMarked;

  DetectedBubble({
    required this.rect,
    required this.fillRatio,
    required this.isMarked,
  });
}

class DetectionResult {
  final List<DetectedBubble> bubbles;
  final List<String?> answers;

  DetectionResult({required this.bubbles, required this.answers});
}

// Painter modificado para escalar corretamente as coordenadas
class BubbleOverlayPainter extends CustomPainter {
  final List<DetectedBubble> bubbles;
  final Size previewSize; // Tamanho da tela/widget
  final Size cameraSize; // Tamanho real da imagem da câmera

  BubbleOverlayPainter({
    required this.bubbles,
    required this.previewSize,
    required this.cameraSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bubbles.isEmpty || cameraSize.isEmpty) return;

    // Calcula os fatores de escala para mapear as coordenadas da imagem para a tela
    final double scaleX = previewSize.width / cameraSize.width;
    final double scaleY = previewSize.height / cameraSize.height;

    for (final bubble in bubbles) {
      // Mapeia o retângulo detectado para as coordenadas da tela
      final displayRect = Rect.fromLTWH(
        bubble.rect.left * scaleX,
        bubble.rect.top * scaleY,
        bubble.rect.width * scaleX,
        bubble.rect.height * scaleY,
      );

      final paint = Paint()
        ..color = bubble.isMarked
            ? Colors.green
            : Colors.blue.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawRect(displayRect, paint);

      if (bubble.isMarked) {
        final fillPaint = Paint()
          ..color = Colors.green.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawRect(displayRect, fillPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BubbleOverlayPainter oldDelegate) {
    return oldDelegate.bubbles != bubbles;
  }
}
