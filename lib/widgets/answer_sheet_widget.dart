import 'package:flutter/material.dart';

import 'question_row_widget.dart';
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

  int _getGridColumns() => availableOptions.length <= 3 ? 2 : 1;

  double get _rowHeight => 52.0;

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
              mainAxisExtent: _rowHeight,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: numQuestions,
            itemBuilder: (context, index) => RepaintBoundary(
              child: QuestionRowWidget(
                questionIndex: index,
                selectedAnswer: answers[index],
                correctAnswer: correctAnswers?[index],
                mode: mode,
                availableOptions: availableOptions,
                onSelectAnswer: onSelectAnswer,
              ),
            ),
          ),
          _buildProgressIndicator(),
        ],
      ),
    );
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
      progressColor = const Color(0xFF4CAF50);
    } else {
      progressText = 'Progresso';
      progressColor = const Color(0xFF4facfe);

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

        if (correctCount + wrongCount > 0) progressText = 'Resultado';
      }
    }

    return Container(
      padding: const EdgeInsets.all(15),
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
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 6,
          ),
          const SizedBox(height: 8),
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
