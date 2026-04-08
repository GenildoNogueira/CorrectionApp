import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exam.dart';
import '../widgets/custom_dropdawn.dart';
import '../widgets/custom_text_field_widget.dart';
import '../widgets/gradient_button_widget.dart';
import '../widgets/answer_sheet_widget.dart';

class ConfigurationScreen extends StatefulWidget {
  final Exam? currentExam;

  const ConfigurationScreen({super.key, this.currentExam});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  final TextEditingController _examNameController = TextEditingController();
  int _numQuestions = 20;
  int _numOptions = 3;
  List<String?> _answerKey = [];

  @override
  void initState() {
    super.initState();
    _initializeAnswerKey();

    if (widget.currentExam != null) {
      _examNameController.text = widget.currentExam!.name;
      _numQuestions = widget.currentExam!.numQuestions;
      _numOptions = widget.currentExam!.numOptions;
      _answerKey = List.from(widget.currentExam!.answerKey);
      _adjustAnswerKeySize();
    }
  }

  void _initializeAnswerKey() {
    _answerKey = List.filled(_numQuestions, null);
  }

  void _adjustAnswerKeySize() {
    if (_answerKey.length < _numQuestions) {
      _answerKey.addAll(List.filled(_numQuestions - _answerKey.length, null));
    } else if (_answerKey.length > _numQuestions) {
      _answerKey = _answerKey.take(_numQuestions).toList();
    }
  }

  @override
  void dispose() {
    _examNameController.dispose();
    super.dispose();
  }

  void _onNumQuestionsChanged(String newValue) {
    setState(() {
      _numQuestions = int.parse(newValue);
      _adjustAnswerKeySize();
    });
  }

  void _onNumOptionsChanged(int newValue) {
    setState(() {
      _numOptions = newValue;
      _validateAnswersForNewOptions();
    });
  }

  void _validateAnswersForNewOptions() {
    final List<String> validOptions = _getValidOptionsForCurrentNum();

    for (int i = 0; i < _answerKey.length; i++) {
      if (_answerKey[i] != null && !validOptions.contains(_answerKey[i])) {
        _answerKey[i] = null;
      }
    }
  }

  List<String> _getValidOptionsForCurrentNum() {
    final List<String> options = ['A', 'B', 'C', 'D', 'E'];
    return options.take(_numOptions).toList();
  }

  void _onSelectAnswer(int questionIndex, String answer) {
    setState(() {
      _answerKey[questionIndex] = answer;
    });
  }

  void _saveConfiguration() {
    final examName = _examNameController.text.trim();

    if (examName.isEmpty) {
      _showSnackBar('Preencha o nome da prova!');
      return;
    }

    final unansweredCount = _answerKey.where((answer) => answer == null).length;
    if (unansweredCount > 0) {
      _showSnackBar('Complete o gabarito! Faltam $unansweredCount respostas.');
      return;
    }

    final exam = Exam(
      name: examName,
      numQuestions: _numQuestions,
      answerKey: _answerKey.cast<String>(),
      numOptions: _numOptions,
    );

    Navigator.of(context).pop(exam);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          spacing: 8,
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.red.shade600,
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Configuração da Prova',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        notificationPredicate: (_) => false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          spacing: 20,
          children: [
            _buildBasicConfigCard(),
            _buildAnswerKeyCard(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicConfigCard() {
    return Card(
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(25),
        child: Column(
          spacing: 15,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              spacing: 15,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(95, 57, 160, 250),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.settings_outlined, size: 24),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informações Básicas',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      Text(
                        'Configure os dados básicos da prova',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            CustomTextFieldWidget(
              controller: _examNameController,
              label: 'Nome da Prova',
              hint: 'Ex: Matemática - 1º Bimestre',
              icon: Icons.assignment,
            ),
            TextFormField(
              initialValue: _numQuestions.toString(),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: 'Quantidade de Questões',
                hintText: 'Ex: 26',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.format_list_numbered),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe um número';
                }

                final int? number = int.tryParse(value);

                if (number == null) {
                  return 'Número inválido';
                }
                if (number < 1) {
                  return 'Mínimo de 1 questão';
                }
                if (number > 100) {
                  return 'Máximo de 100 questões';
                }

                return null;
              },
              onChanged: _onNumQuestionsChanged,
            ),
            CustomDropdawn(
              label: 'Número de Alternativas',
              initialValue: _numOptions,
              value: _getOptionsText(_numOptions),
              itemBuilder: (BuildContext context) => [3, 4, 5].map((int value) {
                return PopupMenuItem<int>(
                  value: value,
                  height: 48,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      _getOptionsText(value),
                      style: TextStyle(
                        color: Color(0xFF09090B),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
              onSelected: _onNumOptionsChanged,
            ),
            // Tips
            _buildTipCard(),
          ],
        ),
      ),
    );
  }

  String _getOptionsText(int value) => switch (value) {
    3 => '3 alternativas (A, B, C)',
    4 => '4 alternativas (A, B, C, D)',
    5 => '5 alternativas (A, B, C, D, E)',
    _ => '$value alternativas',
  };

  Widget _buildAnswerKeyCard() {
    return AnswerSheetWidget(
      numQuestions: _numQuestions,
      answers: _answerKey,
      onSelectAnswer: _onSelectAnswer,
      mode: AnswerSheetMode.answerKey,
      availableOptions: _getValidOptionsForCurrentNum(),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Color(0xFFF0F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF4facfe).withValues(alpha: 0.3)),
      ),
      child: Column(
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(Icons.lightbulb_outline, color: Color(0xFF4facfe), size: 20),
              Text(
                'Dicas Importantes',
                style: TextStyle(
                  color: Color(0xFF4facfe),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            '• Marque a resposta correta para cada questão\n'
            '• Use apenas as alternativas A, B, C, D ou E\n'
            '• Todas as questões devem ser respondidas para salvar',
            style: TextStyle(
              color: Color(0xFF4facfe),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final answeredQuestions = _answerKey
        .where((answer) => answer != null)
        .length;
    final isComplete = answeredQuestions == _numQuestions;
    final examNameFilled = _examNameController.text.trim().isNotEmpty;
    final canSave = isComplete && examNameFilled;

    return Container(
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        spacing: 20,
        children: [
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: canSave ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: canSave ? Colors.green.shade300 : Colors.orange.shade300,
              ),
            ),
            child: Row(
              spacing: 8,
              children: [
                Icon(
                  canSave ? Icons.check_circle : Icons.warning,
                  color: canSave
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
                  size: 20,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canSave
                            ? 'Configuração Completa!'
                            : 'Configuração Incompleta',
                        style: TextStyle(
                          color: canSave
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!canSave)
                        Text(
                          !examNameFilled
                              ? 'Preencha o nome da prova'
                              : 'Complete o gabarito ($answeredQuestions/$_numQuestions questões)',
                          style: TextStyle(
                            color: Colors.orange.shade600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            spacing: 15,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: GradientButtonWidget(
                  text: 'Salvar Configuração',
                  onPressed: canSave ? _saveConfiguration : null,
                  gradientColors: canSave
                      ? [Color(0xFF4facfe), Color(0xFF00f2fe)]
                      : [Colors.grey.shade400, Colors.grey.shade500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
