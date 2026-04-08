import 'package:flutter/material.dart';

import 'answer_sheet_widget.dart';

class QuestionRowWidget extends StatelessWidget {
  final int questionIndex;
  final String? selectedAnswer;
  final String? correctAnswer;
  final AnswerSheetMode mode;
  final List<String> availableOptions;
  final Function(int, String) onSelectAnswer;

  const QuestionRowWidget({
    super.key,
    required this.questionIndex,
    required this.selectedAnswer,
    this.correctAnswer,
    required this.mode,
    required this.availableOptions,
    required this.onSelectAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasAnswer = selectedAnswer != null;
    bool isCorrect = false;
    bool isWrong = false;

    if (mode == AnswerSheetMode.studentAnswers &&
        correctAnswer != null &&
        hasAnswer) {
      isCorrect = selectedAnswer == correctAnswer;
      isWrong = !isCorrect;
    }

    Color borderColor = Colors.grey.shade300;
    if (hasAnswer) {
      if (mode == AnswerSheetMode.answerKey || isCorrect) {
        borderColor = const Color(0xFF4CAF50).withValues(alpha: 0.3);
      } else if (isWrong) {
        borderColor = const Color(0xFFFF5722).withValues(alpha: 0.3);
      } else {
        borderColor = const Color(0xFF4facfe).withValues(alpha: 0.3);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        spacing: 6,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${questionIndex + 1}.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: availableOptions.map((option) {
                final bool isSelected = selectedAnswer == option;
                final bool isCorrectOption =
                    mode == AnswerSheetMode.studentAnswers &&
                    correctAnswer != null &&
                    correctAnswer == option;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: InkResponse(
                        onTap: () => onSelectAnswer(questionIndex, option),
                        containedInkWell: true,
                        borderRadius: BorderRadius.circular(100),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _getOptionBorderColor(isSelected, isCorrectOption),
                              width: 2,
                            ),
                            color: isSelected
                                ? _getSelectedColor(isSelected, isCorrectOption)
                                : Colors.transparent,
                            // ⚡ OTIMIZAÇÃO: BoxShadow removido para salvar GPU
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              option,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (mode == AnswerSheetMode.studentAnswers && correctAnswer != null && hasAnswer)
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: isCorrect ? Colors.green : Colors.red,
              size: 16,
            ),
        ],
      ),
    );
  }

  Color _getSelectedColor(bool isSelected, bool isCorrectOption) {
    if (!isSelected) return Colors.transparent;
    if (mode == AnswerSheetMode.answerKey) return const Color(0xFF4CAF50);

    if (mode == AnswerSheetMode.studentAnswers && correctAnswer != null) {
      return isCorrectOption ? const Color(0xFF4CAF50) : const Color(0xFFFF5722);
    }
    return const Color(0xFF4facfe);
  }

  Color _getOptionBorderColor(bool isSelected, bool isCorrectOption) {
    if (!isSelected) return Colors.grey.shade400;
    if (mode == AnswerSheetMode.answerKey) return const Color(0xFF4CAF50);

    if (mode == AnswerSheetMode.studentAnswers && correctAnswer != null) {
      return isCorrectOption ? const Color(0xFF4CAF50) : const Color(0xFFFF5722);
    }
    return const Color(0xFF4facfe);
  }
}
