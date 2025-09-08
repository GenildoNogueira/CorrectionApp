import 'dart:io';
import 'dart:math' as math;
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../models/exam.dart';
import '../models/image_quality_result.dart';

/// Service for processing images of test answer sheets using OpenCV.
/// Processes an answer sheet image to extract the marked answers.
Future<List<String?>> processAnswerSheet({
  required File imageFile,
  required Exam exam,
}) async {
  try {
    // 1. Image quality validation
    final qualityResult = validateImageQuality(imageFile);
    if (!qualityResult.isValid) {
      throw Exception(qualityResult.message);
    }

    // 2. Image loading with OpenCV
    final bytes = await imageFile.readAsBytes();
    final imageMat = cv.imdecode(bytes, cv.IMREAD_COLOR);

    if (imageMat.isEmpty) {
      throw Exception('Não foi possível decodificar a imagem com OpenCV.');
    }

    // 3. Image processing logic with OpenCV
    final extractedAnswers = await _extractAnswersWithOpenCV(imageMat, exam);

    return extractedAnswers;
  } catch (e) {
    throw Exception('Erro ao processar o gabarito: $e');
  }
}

/// Main implementation with OpenCV to extract responses.
Future<List<String?>> _extractAnswersWithOpenCV(
  cv.Mat image,
  Exam exam,
) async {
  // =======================================================================
  // ETAPA 1: PRÉ-PROCESSAMENTO E DETECÇÃO DA FOLHA
  // =======================================================================
  final gray = cv.cvtColor(image, cv.COLOR_BGR2GRAY);
  final blurred = cv.gaussianBlur(gray, (5, 5), 0);
  // Usar threshold adaptativo para melhor lidar com iluminação irregular
  final thresh = cv.adaptiveThreshold(
    blurred,
    255,
    cv.ADAPTIVE_THRESH_GAUSSIAN_C,
    cv.THRESH_BINARY_INV,
    11,
    2,
  );

  // Limpeza de ruídos usando operações morfológicas.
  // Isso remove pequenos pontos pretos e brancos que podem interferir.
  final kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
  final opening = cv.morphologyEx(
    thresh,
    cv.MORPH_OPEN,
    kernel,
    iterations: 2,
  );

  // Debug: Salvar imagens intermediárias para inspeção (descomente se necessário)
  File(
    'debug_thresh.jpg',
  ).writeAsBytesSync(cv.imencode('.jpg', thresh).$2.toList());
  File(
    'debug_opening.jpg',
  ).writeAsBytesSync(cv.imencode('.jpg', opening).$2.toList());

  // Encontrar o contorno da folha de papel
  final contours = cv
      .findContours(
        opening,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      )
      .$1;

  if (contours.isEmpty) {
    throw Exception(
      'Nenhum contorno encontrado. Verifique a iluminação e o contraste da foto.',
    );
  }

  // Encontrar o maior contorno (assumindo que é a folha)
  cv.VecPoint? largestContour;
  double maxArea = 0;
  for (final contour in contours) {
    final area = cv.contourArea(contour);
    if (area > maxArea) {
      maxArea = area;
      largestContour = contour;
    }
  }

  if (largestContour == null) {
    throw Exception('Não foi possível identificar o contorno do gabarito.');
  }

  // Debug: Desenhar contornos e salvar
  // final debugContours = image.clone();
  // cv.drawContours(debugContours, cv.VecVecPoint.fromList(contours), -1, cv.Scalar(0, 255, 0), 2);
  // File('debug_paper_contours.jpg').writeAsBytesSync(cv.imencode('.jpg', debugContours).$2.toList());

  // =======================================================================
  // ETAPA 2: CORREÇÃO DE PERSPECTIVA
  // =======================================================================
  final peri = cv.arcLength(largestContour, true);
  final approx = cv.approxPolyDP(largestContour, 0.02 * peri, true);

  if (approx.length != 4) {
    throw Exception(
      'Não foi possível detectar os 4 cantos da folha. Tente tirar uma foto de um ângulo mais reto.',
    );
  }

  final warped = _fourPointTransform(image, approx);
  final warpedGray = cv.cvtColor(warped, cv.COLOR_BGR2GRAY);

  // Debug: Salvar warped
  File(
    'debug_warped.jpg',
  ).writeAsBytesSync(cv.imencode('.jpg', warped).$2.toList());

  // =======================================================================
  // ETAPA 3: DETECÇÃO DAS BOLHAS DE RESPOSTA (MÉTODO ROBUSTO)
  // =======================================================================
  final warpedThresh = cv.adaptiveThreshold(
    warpedGray,
    255,
    cv.ADAPTIVE_THRESH_GAUSSIAN_C,
    cv.THRESH_BINARY_INV,
    11,
    2,
  );

  // Debug: Salvar warpedThresh
  File(
    'debug_warped_thresh.jpg',
  ).writeAsBytesSync(cv.imencode('.jpg', warpedThresh).$2.toList());

  // Encontrar todos os contornos na folha corrigida (as bolhas de resposta)
  final bubbleContours = cv
      .findContours(
        warpedThresh,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      )
      .$1;

  final List<cv.VecPoint> questionCnts = [];
  // Filtrar contornos para manter apenas as bolhas
  for (final c in bubbleContours) {
    final rect = cv.boundingRect(c);
    final aspectRatio = rect.width / rect.height.toDouble();

    // Condições para ser uma bolha: proporção próxima de 1 (círculo)
    // e tamanho dentro de uma faixa esperada para não pegar ruídos ou riscos.
    if (rect.width >= 20 &&
        rect.height >= 20 &&
        aspectRatio >= 0.8 &&
        aspectRatio <= 1.2) {
      questionCnts.add(c);
    }
  }

  if (questionCnts.length < exam.numQuestions * exam.availableOptions.length) {
    throw Exception(
      'Não foi possível detectar todas as bolhas de resposta. Verifique a qualidade da imagem e a configuração da prova.',
    );
  }

  // Debug: Desenhar bolhas detectadas
  // final debugBubbles = warped.clone();
  // cv.drawContours(debugBubbles, cv.VecVecPoint.fromList(questionCnts), -1, cv.Scalar(0, 255, 0), 2);
  // File('debug_bubbles.jpg').writeAsBytesSync(cv.imencode('.jpg', debugBubbles).$2.toList());

  // Ordenar os contornos de cima para baixo
  questionCnts.sort(
    (a, b) => cv.boundingRect(a).y.compareTo(cv.boundingRect(b).y),
  );

  final List<String?> answers = [];
  final int numOptions = exam.availableOptions.length;

  // Agrupar as bolhas por questão (em blocos de `numOptions`)
  for (int i = 0; i < questionCnts.length; i += numOptions) {
    // Pegar o grupo de contornos da questão atual
    final group = questionCnts.sublist(
      i,
      math.min(i + numOptions, questionCnts.length),
    );

    if (group.length != numOptions) {
      continue; // Pula se o grupo estiver incompleto
    }

    // Ordenar o grupo da esquerda para a direita
    group.sort(
      (a, b) => cv.boundingRect(a).x.compareTo(cv.boundingRect(b).x),
    );

    int? markedBubbleIndex;
    int maxFilledPixels = -1;
    final List<int> filledPixelsCount = [];

    // Analisar cada bolha no grupo
    for (int j = 0; j < group.length; j++) {
      // Criar uma máscara preta do mesmo tamanho da imagem
      final mask = cv.Mat.zeros(
        warpedThresh.rows,
        warpedThresh.cols,
        cv.MatType.CV_8UC1,
      );
      // Desenhar o contorno da bolha atual em branco na máscara
      cv.drawContours(
        mask,
        cv.VecVecPoint.fromVecPoint(group[j]),
        -1,
        cv.Scalar.all(255),
        thickness: -1,
      );

      // Aplicar a máscara na imagem binarizada para isolar a bolha
      final masked = cv.bitwiseAND(warpedThresh, warpedThresh, mask: mask);
      final total = cv.countNonZero(masked);
      filledPixelsCount.add(total);

      if (total > maxFilledPixels) {
        maxFilledPixels = total;
        markedBubbleIndex = j;
      }
    }

    // Lógica para decidir se a marcação é válida
    // A bolha mais preenchida deve ter uma contagem de pixels consideravelmente
    // maior que a média das outras para ser considerada marcada.
    double meanOthers = 0;
    int countOthers = 0;
    for (int k = 0; k < filledPixelsCount.length; k++) {
      if (k != markedBubbleIndex) {
        meanOthers += filledPixelsCount[k];
        countOthers++;
      }
    }
    meanOthers = countOthers > 0 ? meanOthers / countOthers : 0;

    // O limiar: a bolha marcada deve ter pelo menos 30% mais pixels
    // preenchidos que a média das outras não marcadas.
    final threshold = meanOthers * 1.3;

    if (maxFilledPixels > threshold && markedBubbleIndex != null) {
      answers.add(exam.availableOptions[markedBubbleIndex]);
    } else {
      answers.add(null); // Questão em branco
    }
  }

  // Garante que a lista de respostas tenha o tamanho correto
  while (answers.length < exam.numQuestions) {
    answers.add(null);
  }

  return answers.sublist(0, exam.numQuestions);
}

/// Implementação personalizada da transformação de perspectiva de 4 pontos
cv.Mat _fourPointTransform(cv.Mat image, cv.VecPoint points) {
  final pointsList = <cv.Point>[];
  for (int i = 0; i < points.length; i++) {
    pointsList.add(points[i]);
  }

  final orderedPoints = _orderPoints(pointsList);
  final tl = orderedPoints[0];
  final tr = orderedPoints[1];
  final br = orderedPoints[2];
  final bl = orderedPoints[3];

  final widthA = _distance(br, bl);
  final widthB = _distance(tr, tl);
  final maxWidth = math.max(widthA, widthB).toInt();

  final heightA = _distance(tr, br);
  final heightB = _distance(tl, bl);
  final maxHeight = math.max(heightA, heightB).toInt();

  final srcPoints = cv.VecPoint2f.fromList([
    cv.Point2f(tl.x.toDouble(), tl.y.toDouble()),
    cv.Point2f(tr.x.toDouble(), tr.y.toDouble()),
    cv.Point2f(br.x.toDouble(), br.y.toDouble()),
    cv.Point2f(bl.x.toDouble(), bl.y.toDouble()),
  ]);

  final dstPoints = cv.VecPoint2f.fromList([
    cv.Point2f(0.0, 0.0),
    cv.Point2f(maxWidth.toDouble() - 1, 0.0),
    cv.Point2f(maxWidth.toDouble() - 1, maxHeight.toDouble() - 1),
    cv.Point2f(0.0, maxHeight.toDouble() - 1),
  ]);

  final M = cv.getPerspectiveTransform2f(srcPoints, dstPoints);
  final warped = cv.warpPerspective(image, M, (maxWidth, maxHeight));

  return warped;
}

/// Ordena os pontos em: top-left, top-right, bottom-right, bottom-left
List<cv.Point> _orderPoints(List<cv.Point> points) {
  final ordered = List<cv.Point>.filled(4, cv.Point(0, 0));
  final sums = points.map((p) => p.x + p.y).toList();
  final diffs = points.map((p) => p.x - p.y).toList();

  int minSumIndex = 0, maxSumIndex = 0;
  int minDiffIndex = 0, maxDiffIndex = 0;

  for (int i = 1; i < points.length; i++) {
    if (sums[i] < sums[minSumIndex]) minSumIndex = i;
    if (sums[i] > sums[maxSumIndex]) maxSumIndex = i;
    if (diffs[i] < diffs[minDiffIndex]) minDiffIndex = i;
    if (diffs[i] > diffs[maxDiffIndex]) maxDiffIndex = i;
  }

  // O ponto com a menor soma (x+y) é o superior esquerdo (top-left)
  ordered[0] = points[minSumIndex];
  // O ponto com a maior soma (x+y) é o inferior direito (bottom-right)
  ordered[2] = points[maxSumIndex];
  // O ponto com a menor diferença (x-y) é o superior direito (top-right)
  ordered[1] = points[minDiffIndex];
  // O ponto com a maior diferença (x-y) é o inferior esquerdo (bottom-left)
  ordered[3] = points[maxDiffIndex];

  return ordered;
}

/// Calcula a distância euclidiana entre dois pontos
double _distance(cv.Point p1, cv.Point p2) {
  return math.sqrt(math.pow(p2.x - p1.x, 2) + math.pow(p2.y - p1.y, 2));
}

/// Valida a qualidade da imagem antes do processamento.
ImageQualityResult validateImageQuality(File imageFile) {
  try {
    final fileSizeKB = imageFile.lengthSync() / 1024;

    if (fileSizeKB < 100) {
      return ImageQualityResult(
        isValid: false,
        message: 'Imagem muito pequena. A resolução pode ser insuficiente.',
      );
    }
    if (fileSizeKB > 10240) {
      return ImageQualityResult(
        isValid: false,
        message: 'Imagem muito grande. Comprima a imagem antes de enviar.',
      );
    }
    return ImageQualityResult(
      isValid: true,
      message: 'Qualidade da imagem adequada para processamento.',
    );
  } catch (e) {
    return ImageQualityResult(
      isValid: false,
      message: 'Erro ao validar a imagem: $e',
    );
  }
}
