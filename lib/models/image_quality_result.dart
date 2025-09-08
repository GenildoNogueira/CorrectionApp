/// Representa o resultado da validação de qualidade da imagem.
class ImageQualityResult {
  final bool isValid;
  final String message;

  ImageQualityResult({
    required this.isValid,
    required this.message,
  });
}
