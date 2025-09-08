class Exam {
  final String name;
  final int numQuestions;
  final int numOptions;
  final List<String> answerKey;

  const Exam({
    required this.name,
    required this.numQuestions,
    required this.numOptions,
    required this.answerKey,
  });

  // Lista de opções baseada no número configurado
  List<String> get availableOptions {
    const allOptions = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];
    return allOptions.take(numOptions).toList();
  }

  // Método para validar se uma resposta é válida
  bool isValidAnswer(String answer) {
    return availableOptions.contains(answer);
  }

  // Método para copiar com alterações
  Exam copyWith({
    String? name,
    int? numQuestions,
    int? numOptions,
    List<String>? answerKey,
  }) {
    return Exam(
      name: name ?? this.name,
      numQuestions: numQuestions ?? this.numQuestions,
      numOptions: numOptions ?? this.numOptions,
      answerKey: answerKey ?? this.answerKey,
    );
  }

  @override
  String toString() {
    return 'Exam(name: $name, numQuestions: $numQuestions, numOptions: $numOptions, answerKey: $answerKey)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Exam &&
        other.name == name &&
        other.numQuestions == numQuestions &&
        other.numOptions == numOptions &&
        _listEquals(other.answerKey, answerKey);
  }

  @override
  int get hashCode {
    return name.hashCode ^
        numQuestions.hashCode ^
        numOptions.hashCode ^
        answerKey.hashCode;
  }
}

class ExamResult {
  final int correctCount;
  final int wrongCount;
  final double percentage;
  final int totalQuestions;

  ExamResult({
    required this.correctCount,
    required this.wrongCount,
    required this.percentage,
    int? totalQuestions,
  }) : totalQuestions = totalQuestions ?? (correctCount + wrongCount);

  int get blankCount => totalQuestions - correctCount - wrongCount;

  @override
  String toString() {
    return 'ExamResult(correct: $correctCount, wrong: $wrongCount, percentage: ${percentage.toStringAsFixed(1)}%)';
  }
}

// Função auxiliar para comparar listas
bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
