import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../models/exam.dart';
import '../screens/realtime_detection_screen.dart';
import '../services/image_processing_service.dart';
import '../widgets/gradient_button_widget.dart';

class CameraSectionWidget extends StatelessWidget {
  final File? capturedImage;
  final CameraController? cameraController;
  final Exam? currentExam;
  final VoidCallback? onStartCamera;
  final VoidCallback? onCaptureImage;
  final VoidCallback? onPickFromGallery;
  final VoidCallback? onProcessAnswers;
  final Function(List<String?>) onAnswersExtracted;

  const CameraSectionWidget({
    super.key,
    this.capturedImage,
    this.cameraController,
    this.currentExam,
    this.onStartCamera,
    this.onCaptureImage,
    this.onPickFromGallery,
    this.onProcessAnswers,
    required this.onAnswersExtracted,
  });

  Future<void> _openRealtimeDetection(BuildContext context) async {
    if (currentExam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure a prova primeiro!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('Nenhuma câmera disponível');
      }

      if (context.mounted) {
        final result = await Navigator.of(context).push<List<String?>>(
          MaterialPageRoute(
            builder: (context) => RealtimeDetectionScreen(
              camera: cameras.first,
              exam: currentExam!,
            ),
          ),
        );

        if (result != null && result.isNotEmpty) {
          onAnswersExtracted(result);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Respostas extraídas: ${result.where((a) => a != null).length}/${currentExam!.numQuestions}',
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao abrir detecção em tempo real: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _extractAnswersFromImage(BuildContext context) async {
    if (capturedImage == null || currentExam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Capture uma imagem e configure a prova primeiro!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processando imagem...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Processa a imagem
      final answers = await processAnswerSheet(
        imageFile: capturedImage!,
        exam: currentExam!,
      );

      Navigator.of(context).pop();

      onAnswersExtracted(answers);
    } catch (e) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao processar imagem: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF764ba2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Color(0xFF764ba2),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Captura e Processamento',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _buildPreview(context),
          ),

          const SizedBox(height: 20),

          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: GradientButtonWidget(
                  text: 'Detecção em Tempo Real ✨',
                  onPressed: currentExam != null
                      ? () => _openRealtimeDetection(context)
                      : null,
                  height: 55,
                  gradientColors: const [
                    Color(0xFF667eea),
                    Color(0xFF764ba2),
                  ],
                  //icon: Icons.auto_awesome,
                ),
              ),

              const SizedBox(height: 12),

              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'ou',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onStartCamera,
                      icon: const Icon(Icons.camera_alt, size: 20),
                      label: const Text('Câmera'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF764ba2),
                        side: const BorderSide(color: Color(0xFF764ba2)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickFromGallery,
                      icon: const Icon(Icons.photo_library, size: 20),
                      label: const Text('Galeria'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF764ba2),
                        side: const BorderSide(color: Color(0xFF764ba2)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (capturedImage != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _extractAnswersFromImage(context),
                    icon: const Icon(Icons.auto_fix_high, color: Colors.white),
                    label: const Text(
                      'Extrair Respostas da Imagem',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (capturedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              capturedImage!,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    const Text(
                      'Imagem Capturada',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (cameraController != null &&
        cameraController!.value.isInitialized) {
      // Mostra o preview da câmera
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(cameraController!),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton(
                  onPressed: onCaptureImage,
                  backgroundColor: Colors.white,
                  child: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF764ba2),
                    size: 28,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Câmera Ativa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            currentExam == null
                ? 'Configure a prova para começar'
                : 'Use "Detecção em Tempo Real" para melhor precisão\nou capture/selecione uma imagem',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          if (currentExam != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'IA Recomenda: Detecção em Tempo Real',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }
  }
}
