import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

import '../models/exam.dart';
import '../widgets/configuration_status_widget.dart';
import '../widgets/camera_section_widget.dart';
import '../widgets/answer_sheet_widget.dart';
import '../widgets/results_widget.dart';
import '../widgets/gradient_button_widget.dart';
import 'configuration_screen.dart';

class CorrectionScreen extends StatefulWidget {
  const CorrectionScreen({super.key});

  @override
  State<CorrectionScreen> createState() => _CorrectionScreenState();
}

class _CorrectionScreenState extends State<CorrectionScreen>
    with TickerProviderStateMixin {
  Exam? _currentExam;
  List<String?> _studentAnswers = [];
  bool _showResults = false;
  ExamResult? _examResult;
  bool _answersExtractedFromImage = false;

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  File? _capturedImage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _startCamera() async {
    if (_cameras != null && _cameras!.isNotEmpty) {
      _cameraController = CameraController(_cameras![0], ResolutionPreset.high);

      try {
        await _cameraController!.initialize();
        setState(() {});
      } catch (e) {
        print('Error starting camera: $e');
        _showSnackBar('Erro ao iniciar câmera: $e', isError: true);
      }
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final XFile image = await _cameraController!.takePicture();
        setState(() {
          _capturedImage = File(image.path);
          _answersExtractedFromImage =
              false; // Reset flag when new image is captured
        });
        _cameraController!.dispose();
        _cameraController = null;
        _showSnackBar(
          'Imagem capturada! Agora você pode extrair as respostas automaticamente.',
        );
      } catch (e) {
        _showSnackBar('Erro ao capturar imagem: $e', isError: true);
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _capturedImage = File(image.path);
        _answersExtractedFromImage = false;
      });
      _showSnackBar(
        'Imagem selecionada! Use "Extrair Respostas" para processar automaticamente.',
      );
    }
  }

  Future<void> _navigateToConfiguration() async {
    final result = await Navigator.of(context).push<Exam>(
      MaterialPageRoute(
        builder: (context) => ConfigurationScreen(currentExam: _currentExam),
      ),
    );

    if (result != null) {
      setState(() {
        _currentExam = result;
        _studentAnswers = List.filled(_currentExam!.numQuestions, null);
        _showResults = false;
        _examResult = null;
        _capturedImage = null;
        _answersExtractedFromImage = false;
      });
      _showSnackBar('Prova configurada com sucesso!');
    }
  }

  void _selectAnswer(int questionIndex, String answer) {
    // Valida se a resposta é válida para o exame atual
    if (_currentExam != null && _currentExam!.isValidAnswer(answer)) {
      setState(() {
        _studentAnswers[questionIndex] = answer;
      });
      // Debug Snackbar: Mostrar qual resposta foi selecionada manualmente
      _showSnackBar('Questão $questionIndex marcada manualmente como $answer');
    }
  }

  void _onAnswersExtracted(List<String?> extractedAnswers) {
    if (_currentExam == null) return;

    setState(() {
      for (
        int i = 0;
        i < extractedAnswers.length && i < _studentAnswers.length;
        i++
      ) {
        if (extractedAnswers[i] != null) {
          _studentAnswers[i] = extractedAnswers[i];
        }
      }
      _answersExtractedFromImage = true;
    });

    // Mostra estatísticas da extração
    final extractedCount = extractedAnswers
        .where((answer) => answer != null)
        .length;
    final blankCount = _currentExam!.numQuestions - extractedCount;

    _showSnackBar(
      'Extraídas $extractedCount respostas. $blankCount questões em branco. Verifique e corrija se necessário.',
    );

    final debugAnswers = extractedAnswers
        .take(5)
        .map((a) => a ?? 'branco')
        .join(', ');
    _showSnackBar(
      'Debug: Primeiras respostas extraídas: $debugAnswers',
      isError: false,
    );
  }

  void _processAnswers() {
    if (_currentExam == null) {
      _showSnackBar('Configure a prova primeiro!', isError: true);
      return;
    }

    if (_studentAnswers.every((answer) => answer == null)) {
      _showSnackBar(
        'Nenhuma resposta encontrada! Extraia respostas da imagem ou marque manualmente.',
        isError: true,
      );
      return;
    }

    final answeredCount = _studentAnswers.where((a) => a != null).length;
    _showSnackBar('Debug: Processando $answeredCount respostas marcadas');

    int correct = 0;
    int wrong = 0;
    int blank = 0;

    for (int i = 0; i < _currentExam!.answerKey.length; i++) {
      if (_studentAnswers[i] != null) {
        if (_studentAnswers[i] == _currentExam!.answerKey[i]) {
          correct++;
        } else {
          wrong++;
        }
      } else {
        blank++;
      }
    }

    _showSnackBar(
      'Debug: Corretas: $correct | Erradas: $wrong | Brancas: $blank',
    );

    final result = ExamResult(
      correctCount: correct,
      wrongCount: wrong,
      percentage: _currentExam!.numQuestions > 0
          ? (correct / _currentExam!.numQuestions) * 100
          : 0,
      totalQuestions: _currentExam!.numQuestions,
    );

    setState(() {
      _examResult = result;
      _showResults = true;
    });

    _animationController.reset();
    _animationController.forward();

    // Mostra informação adicional se as respostas foram extraídas da imagem
    if (_answersExtractedFromImage) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _showSnackBar(
          '✨ Correção concluída com respostas extraídas automaticamente da imagem!',
        );
      });
    }
  }

  void _resetExam() {
    setState(() {
      if (_currentExam != null) {
        _studentAnswers = List.filled(_currentExam!.numQuestions, null);
      }
      _showResults = false;
      _examResult = null;
      _capturedImage = null;
      _answersExtractedFromImage = false;
    });
    _cameraController?.dispose();
    _cameraController = null;
    _showSnackBar('Prova resetada. Pronta para nova correção!');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          spacing: 8,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: _buildHeader(),
      ),
      floatingActionButton: _buildFloatingActionButtons(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          spacing: 20,
          children: [
            if (_currentExam != null)
              ConfigurationStatusWidget(
                exam: _currentExam!,
                onEdit: _navigateToConfiguration,
              ),

            if (_currentExam != null) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  const double mobileBreakpoint = 700;
                  if (constraints.maxWidth < mobileBreakpoint) {
                    // Use Column for mobile layout
                    return Column(
                      spacing: 20,
                      children: [
                        CameraSectionWidget(
                          capturedImage: _capturedImage,
                          cameraController: _cameraController,
                          currentExam: _currentExam,
                          onStartCamera: _startCamera,
                          onCaptureImage: _captureImage,
                          onPickFromGallery: _pickImageFromGallery,
                          onProcessAnswers: _processAnswers,
                          onAnswersExtracted: _onAnswersExtracted,
                        ),
                        AnswerSheetWidget(
                          numQuestions: _currentExam!.numQuestions,
                          answers: _studentAnswers,
                          onSelectAnswer: _selectAnswer,
                          availableOptions: _currentExam!.availableOptions,
                          correctAnswers: _showResults
                              ? _currentExam!.answerKey.cast<String?>()
                              : null,
                          title: _answersExtractedFromImage
                              ? 'Gabarito (Extraído da Imagem)'
                              : 'Gabarito Manual',
                        ),
                      ],
                    );
                  } else {
                    // Use Row for wider layouts (tablet/desktop)
                    return Row(
                      spacing: 20,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CameraSectionWidget(
                            capturedImage: _capturedImage,
                            cameraController: _cameraController,
                            currentExam: _currentExam,
                            onStartCamera: _startCamera,
                            onCaptureImage: _captureImage,
                            onPickFromGallery: _pickImageFromGallery,
                            onProcessAnswers: _processAnswers,
                            onAnswersExtracted: _onAnswersExtracted,
                          ),
                        ),
                        Expanded(
                          child: AnswerSheetWidget(
                            numQuestions: _currentExam!.numQuestions,
                            answers: _studentAnswers,
                            onSelectAnswer: _selectAnswer,
                            availableOptions: _currentExam!.availableOptions,
                            correctAnswers: _showResults
                                ? _currentExam!.answerKey.cast<String?>()
                                : null,
                            title: _answersExtractedFromImage
                                ? 'Gabarito (Extraído da Imagem)'
                                : 'Gabarito Manual',
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),

              // Automatic extraction status
              if (_answersExtractedFromImage)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          spacing: 4,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Respostas Extraídas Automaticamente',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              'As respostas foram detectadas da imagem. Verifique se estão corretas antes de processar.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (_showResults && _examResult != null)
                ResultsWidget(
                  result: _examResult!,
                  totalQuestions: _currentExam!.numQuestions,
                  fadeAnimation: _fadeAnimation,
                  slideAnimation: _slideAnimation,
                ),
            ] else
              _buildWelcomeSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.blue,
      ),
      child: SafeArea(
        child: Row(
          spacing: 12,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.grading_rounded, color: Colors.white, size: 30),
            const Text(
              'Corretor de Provas IA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_answersExtractedFromImage) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    const Text(
                      'IA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          spacing: 15,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            const Text('👋', style: TextStyle(fontSize: 50)),
            const Text(
              'Bem-vindo!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            Text(
              'Para começar, configure os detalhes da prova, como o número de questões, alternativas e o gabarito.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                spacing: 12,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.blue.shade700),
                  Expanded(
                    child: Text(
                      '✨ Novidade: Extração automática de respostas usando IA!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GradientButtonWidget(
              text: 'Configurar Prova',
              onPressed: _navigateToConfiguration,
              height: 55,
              gradientColors: const [
                Color(0xFF667eea),
                Color(0xFF764ba2),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButtons() {
    if (_currentExam == null) return null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          onPressed: _resetExam,
          tooltip: 'Resetar Prova',
          backgroundColor: Colors.orange.shade700,
          heroTag: 'resetFab',
          child: const Icon(Icons.refresh, color: Colors.white),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
          onPressed: _navigateToConfiguration,
          tooltip: 'Editar Configuração',
          icon: const Icon(Icons.settings, color: Colors.white),
          label: const Text(
            'Configurar',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF764ba2),
          heroTag: 'configFab',
        ),
      ],
    );
  }
}
