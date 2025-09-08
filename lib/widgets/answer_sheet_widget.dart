import 'package:flutter/material.dart';

import 'section_container_widget.dart';

enum AnswerSheetMode { answerKey, studentAnswers }

class AnswerSheetWidget extends StatelessWidget {
  final int numQuestions;
  final List<String?> answers;
  final Function(int, String) onSelectAnswer;
  final AnswerSheetMode mode;
  final List<String?>? correctAnswers;
  final List<String> availableOptions;
  final String? title;
  final bool showExtractedIndicator;

  const AnswerSheetWidget({
    super.key,
    required this.numQuestions,
    required this.answers,
    required this.onSelectAnswer,
    required this.availableOptions,
    this.mode = AnswerSheetMode.studentAnswers,
    this.correctAnswers,
    this.title,
    this.showExtractedIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainerWidget(
      title: title ?? 'Gabarito do Aluno',
      icon: showExtractedIndicator
          ? const Icon(Icons.auto_awesome, size: 20)
          : const Icon(Icons.assignment_outlined, size: 20),
      child: Column(
        spacing: 15,
        children: [
          // Indicador de extração automática
          if (showExtractedIndicator)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                spacing: 8,
                children: [
                  Icon(
                    Icons.smart_toy,
                    color: Colors.purple.shade700,
                    size: 20,
                  ),
                  Expanded(
                    child: Text(
                      'Respostas detectadas automaticamente pela IA. Verifique e ajuste se necessário.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _getGridColumns(),
              childAspectRatio: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: numQuestions,
            itemBuilder: (context, index) => _buildQuestionRow(index),
          ),
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  int _getGridColumns() {
    if (availableOptions.length <= 3) return 2;
    if (availableOptions.length <= 6) return 1;
    return 1;
  }

  Widget _buildQuestionRow(int questionIndex) {
    final bool hasAnswer = answers[questionIndex] != null;
    bool isCorrect = false;
    bool isWrong = false;

    if (mode == AnswerSheetMode.studentAnswers &&
        correctAnswers != null &&
        hasAnswer &&
        correctAnswers![questionIndex] != null) {
      isCorrect = answers[questionIndex] == correctAnswers![questionIndex];
      isWrong = !isCorrect;
    }

    Color borderColor = Colors.grey.shade300;
    if (hasAnswer) {
      if (mode == AnswerSheetMode.answerKey || isCorrect) {
        borderColor = Color(
          0xFF4CAF50,
        ).withValues(alpha: 0.3);
      } else if (isWrong) {
        borderColor = Color(
          0xFFFF5722,
        ).withValues(alpha: 0.3);
      } else {
        borderColor = Color(0xFF4facfe).withValues(alpha: 0.3);
      }
    }

    final double circleSize = _getCircleSize();

    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        spacing: 10,
        children: [
          Text(
            '${questionIndex + 1}.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Row(
              children: availableOptions.map((option) {
                final bool isSelected = answers[questionIndex] == option;
                final bool isCorrectOption =
                    mode == AnswerSheetMode.studentAnswers &&
                    correctAnswers != null &&
                    correctAnswers![questionIndex] == option;

                return InkResponse(
                  onTap: () => onSelectAnswer(questionIndex, option),
                  containedInkWell: true,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getOptionBorderColor(
                          isSelected,
                          isCorrectOption,
                        ),
                        width: 2,
                      ),
                      color: isSelected
                          ? Color(0xFFFF5722)
                          : Colors.transparent,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _getOptionShadowColor(isCorrectOption),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      option,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                        fontSize: _getFontSize(),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (mode == AnswerSheetMode.studentAnswers &&
              correctAnswers != null &&
              hasAnswer)
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : Colors.red,
                size: 14,
              ),
            ),
        ],
      ),
    );
  }

  double _getCircleSize() => switch (availableOptions.length) {
    3 => 36.0,
    4 => 32.0,
    5 => 28.0,
    _ => 30.0,
  };

  // Ajusta o tamanho da fonte baseado no número de opções
  double _getFontSize() => switch (availableOptions.length) {
    3 => 14.0,
    4 => 13.0,
    5 => 12.0,
    _ => 12.0,
  };

  Color _getOptionBorderColor(bool isSelected, bool isCorrectOption) {
    if (!isSelected) return Colors.grey.shade400;

    if (mode == AnswerSheetMode.answerKey) {
      return Color(0xFF4CAF50); // Verde para gabarito
    }

    if (mode == AnswerSheetMode.studentAnswers && correctAnswers != null) {
      return isCorrectOption
          ? Color(0xFF4CAF50)
          : Color(0xFFFF5722); // Verde/Vermelho
    }

    return Color(0xFF4facfe); // Azul padrão
  }

  Color _getOptionShadowColor(bool isCorrectOption) {
    if (mode == AnswerSheetMode.answerKey) {
      return Color(0xFF4CAF50).withValues(alpha: 0.3);
    }

    if (mode == AnswerSheetMode.studentAnswers && correctAnswers != null) {
      return isCorrectOption
          ? Color(0xFF4CAF50).withValues(alpha: 0.3)
          : Color(0xFFFF5722).withValues(alpha: 0.3);
    }

    return Color(0xFF4facfe).withValues(alpha: 0.3);
  }

  Widget _buildProgressIndicator() {
    final int answeredQuestions = answers
        .where((answer) => answer != null)
        .length;
    final double progress = numQuestions > 0
        ? answeredQuestions / numQuestions
        : 0;

    String progressText;
    Color progressColor;

    if (mode == AnswerSheetMode.answerKey) {
      progressText = 'Gabarito';
      progressColor = Color(0xFF4CAF50);
    } else {
      progressText = 'Progresso';
      progressColor = Color(0xFF4facfe);

      // Se temos o gabarito, mostrar também acertos/erros
      if (correctAnswers != null) {
        int correctCount = 0;
        int wrongCount = 0;

        for (int i = 0; i < answers.length; i++) {
          if (answers[i] != null && correctAnswers![i] != null) {
            if (answers[i] == correctAnswers![i]) {
              correctCount++;
            } else {
              wrongCount++;
            }
          }
        }

        if (correctCount + wrongCount > 0) {
          progressText = 'Resultado';
        }
      }
    }

    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                progressText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                '$answeredQuestions/$numQuestions questões',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 6,
          ),
          SizedBox(height: 8),
          _buildProgressText(progress, answeredQuestions),
        ],
      ),
    );
  }

  Widget _buildProgressText(double progress, int answeredQuestions) {
    if (mode == AnswerSheetMode.studentAnswers &&
        correctAnswers != null &&
        answeredQuestions > 0) {
      int correctCount = 0;
      int wrongCount = 0;

      for (int i = 0; i < answers.length; i++) {
        if (answers[i] != null && correctAnswers![i] != null) {
          if (answers[i] == correctAnswers![i]) {
            correctCount++;
          } else {
            wrongCount++;
          }
        }
      }

      if (correctCount + wrongCount > 0) {
        final double percentage =
            (correctCount / (correctCount + wrongCount)) * 100;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${percentage.toInt()}% de acerto',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '✅ $correctCount  ❌ $wrongCount',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }
    }

    return Text(
      '${(progress * 100).toInt()}% concluído',
      style: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
