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
      final originalWidth = image.width;
      final originalHeight = image.height;

      // 1. Redimensiona para tamanho fixo de processamento
      const procWidth = 640;
      const procHeight = 480;
      final resized = cv.resize(image, (procWidth, procHeight));

      // 2. Converte para cinza e suaviza
      final gray = cv.cvtColor(resized, cv.COLOR_BGR2GRAY);
      final blurred = cv.gaussianBlur(gray, (9, 9), 2);

      // 3. Threshold adaptativo com parâmetros mais robustos
      final thresh = cv.adaptiveThreshold(
        blurred,
        255,
        cv.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv.THRESH_BINARY_INV,
        15,
        4,
      );

      // 4. Fechamento morfológico (preenche buracos nas bolhas marcadas)
      //    seguido de abertura (remove ruído pequeno)
      final kernelClose = cv.getStructuringElement(cv.MORPH_ELLIPSE, (5, 5));
      final kernelOpen = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
      final closed = cv.morphologyEx(thresh, cv.MORPH_CLOSE, kernelClose);
      final cleaned = cv.morphologyEx(closed, cv.MORPH_OPEN, kernelOpen);

      final contours = cv
          .findContours(cleaned, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE)
          .$1;

      final bubbles = <DetectedBubble>[];
      final scaleX = originalWidth / procWidth;
      final scaleY = originalHeight / procHeight;

      for (final contour in contours) {
        final area = cv.contourArea(contour);

        // FIX 1 – faixa de área realista para bolhas de gabarito
        if (area < 200 || area > 6000) continue;

        final rect = cv.boundingRect(contour);
        final aspectRatio = rect.width / rect.height.toDouble();
        if (aspectRatio < 0.55 || aspectRatio > 1.45) continue;

        // FIX 2 – filtro de circularidade: 4π·A / P²  (círculo perfeito = 1.0)
        final perimeter = cv.arcLength(contour, true);
        if (perimeter <= 0) continue;
        final circularity = (4 * 3.14159265 * area) / (perimeter * perimeter);
        if (circularity < 0.55)
          continue; // descarta retângulos e formas irregulares

        // Coordenadas no espaço original
        final scaledRect = Rect.fromLTWH(
          rect.x * scaleX,
          rect.y * scaleY,
          rect.width * scaleX,
          rect.height * scaleY,
        );

        // FIX 3 – fill ratio correto:
        //   • mask: pixels DENTRO do contorno (forma real da bolha)
        //   • filledPx: pixels brancos do threshold dentro dessa máscara
        //   • totalPx: total de pixels da máscara  → divisão consistente
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
          thickness: -1, // preenche o interior
        );
        final totalPx = cv.countNonZero(mask);
        final maskedImg = cv.bitwiseAND(cleaned, cleaned, mask: mask);
        final filledPx = cv.countNonZero(maskedImg);

        final fillRatio = totalPx > 0 ? filledPx / totalPx : 0.0;

        bubbles.add(
          DetectedBubble(
            rect: scaledRect,
            fillRatio: fillRatio,
            isMarked:
                fillRatio >
                0.50, // threshold ligeiramente mais alto = menos falsos positivos
          ),
        );
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

    // FIX 4 – tolerância dinâmica baseada no tamanho médio real das bolhas
    final avgH =
        bubbles.map((b) => b.rect.height).reduce((a, b) => a + b) /
        bubbles.length;
    final rowTolerance =
        avgH * 0.6; // 60 % da altura média → agrupa mesma linha

    // Agrupa por linhas usando o CENTRO vertical (não o topo)
    bubbles.sort((a, b) {
      final dy = a.rect.center.dy - b.rect.center.dy;
      if (dy.abs() < rowTolerance)
        return a.rect.center.dx.compareTo(b.rect.center.dx);
      return dy.compareTo(0);
    });

    final rows = <List<DetectedBubble>>[];
    var current = [bubbles.first];

    for (int i = 1; i < bubbles.length; i++) {
      final rowCenterY =
          current.map((b) => b.rect.center.dy).reduce((a, b) => a + b) /
          current.length;

      if ((bubbles[i].rect.center.dy - rowCenterY).abs() < rowTolerance) {
        current.add(bubbles[i]);
      } else {
        rows.add(List.from(current));
        current = [bubbles[i]];
      }
    }
    rows.add(current);

    // Ordena linhas de cima para baixo pelo centro médio
    rows.sort((a, b) {
      final aY =
          a.map((b) => b.rect.center.dy).reduce((x, y) => x + y) / a.length;
      final bY =
          b.map((b) => b.rect.center.dy).reduce((x, y) => x + y) / b.length;
      return aY.compareTo(bY);
    });

    final numOptions = widget.exam.availableOptions.length;
    final answers = <String?>[];

    for (final row in rows) {
      if (row.length != numOptions) continue; // ignora linhas incompletas

      row.sort((a, b) => a.rect.center.dx.compareTo(b.rect.center.dx));

      // Encontra a bolha com maior fillRatio acima do limiar mínimo
      int bestIdx = -1;
      double bestFill = 0.45; // limiar mínimo para considerar marcada

      for (int i = 0; i < row.length; i++) {
        if (row[i].fillRatio > bestFill) {
          bestFill = row[i].fillRatio;
          bestIdx = i;
        }
      }

      if (bestIdx == -1) {
        answers.add(null); // nenhuma marcada → em branco
        continue;
      }

      // FIX 5 – anti-ambiguidade: a bolha vencedora precisa ser
      // pelo menos 15 pp mais preenchida que a segunda
      final secondBest = row
          .asMap()
          .entries
          .where((e) => e.key != bestIdx)
          .map((e) => e.value.fillRatio)
          .fold(0.0, (max, v) => v > max ? v : max);

      if (row[bestIdx].fillRatio - secondBest >= 0.15) {
        answers.add(widget.exam.availableOptions[bestIdx]);
      } else {
        answers.add(null); // duas bolhas muito parecidas → anula
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
