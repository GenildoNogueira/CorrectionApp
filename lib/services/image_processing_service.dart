import 'dart:io';
import 'dart:math' as math;
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../models/exam.dart';
import '../models/image_quality_result.dart';

Future<List<String?>> processAnswerSheet({
  required File imageFile,
  required Exam exam,
}) async {
  try {
    final qualityResult = validateImageQuality(imageFile);
    if (!qualityResult.isValid) throw Exception(qualityResult.message);

    final bytes = await imageFile.readAsBytes();
    final imageMat = cv.imdecode(bytes, cv.IMREAD_COLOR);

    if (imageMat.isEmpty) {
      throw Exception('Não foi possível decodificar a imagem.');
    }

    return await _extractAnswersWithOpenCV(imageMat, exam);
  } catch (e) {
    throw Exception('Erro ao processar o gabarito: $e');
  }
}

Future<List<String?>> _extractAnswersWithOpenCV(
  cv.Mat image,
  Exam exam,
) async {
  // =========================================================================
  // ETAPA 1: PRÉ-PROCESSAMENTO
  // =========================================================================
  final gray = cv.cvtColor(image, cv.COLOR_BGR2GRAY);
  final blurred = cv.gaussianBlur(gray, (5, 5), 0);
  final thresh = cv.adaptiveThreshold(
    blurred,
    255,
    cv.ADAPTIVE_THRESH_GAUSSIAN_C,
    cv.THRESH_BINARY_INV,
    11,
    2,
  );
  final kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
  final opening = cv.morphologyEx(thresh, cv.MORPH_OPEN, kernel, iterations: 2);

  // =========================================================================
  // ETAPA 2: CORREÇÃO DE PERSPECTIVA (com fallback gracioso)
  // =========================================================================
  cv.Mat workingImage;

  try {
    workingImage = _attemptPerspectiveCorrection(image, opening);
  } catch (_) {
    // FIX 1 – se não encontrar 4 cantos, usa a imagem original redimensionada
    // em vez de lançar exceção e abortar tudo
    workingImage = cv.resize(image, (800, 1000));
  }

  // =========================================================================
  // ETAPA 3: DETECÇÃO DE BOLHAS NA IMAGEM CORRIGIDA
  // =========================================================================
  final wGray = cv.cvtColor(workingImage, cv.COLOR_BGR2GRAY);
  final wBlurred = cv.gaussianBlur(wGray, (9, 9), 2);

  // FIX 2 – fechamento morfológico ANTES do threshold para preencher bolhas
  // parcialmente marcadas (lápis fraco, marcação leve)
  final kernelClose = cv.getStructuringElement(cv.MORPH_ELLIPSE, (5, 5));
  final kernelOpen = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
  final wThreshRaw = cv.adaptiveThreshold(
    wBlurred,
    255,
    cv.ADAPTIVE_THRESH_GAUSSIAN_C,
    cv.THRESH_BINARY_INV,
    15,
    4,
  );
  final wThreshClosed = cv.morphologyEx(
    wThreshRaw,
    cv.MORPH_CLOSE,
    kernelClose,
  );
  final wThresh = cv.morphologyEx(wThreshClosed, cv.MORPH_OPEN, kernelOpen);

  final rawContours = cv
      .findContours(
        wThresh,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      )
      .$1;

  // FIX 3 – tamanho mínimo/máximo dinâmico baseado na área útil da imagem
  final imgArea = workingImage.width * workingImage.height;
  final minBubbleArea = imgArea * 0.0003; // 0.03 % da imagem
  final maxBubbleArea = imgArea * 0.012; // 1.2 % da imagem

  final List<cv.VecPoint> bubbleContours = [];
  for (final c in rawContours) {
    final area = cv.contourArea(c);
    if (area < minBubbleArea || area > maxBubbleArea) continue;

    final rect = cv.boundingRect(c);
    final aspectRatio = rect.width / rect.height.toDouble();
    if (aspectRatio < 0.6 || aspectRatio > 1.4) continue;

    // FIX 4 – filtro de circularidade (elimina traços, ruídos, bordas)
    final perimeter = cv.arcLength(c, true);
    if (perimeter <= 0) continue;
    final circularity = (4 * math.pi * area) / (perimeter * perimeter);
    if (circularity < 0.50) continue;

    bubbleContours.add(c);
  }

  final expectedTotal = exam.numQuestions * exam.availableOptions.length;
  if (bubbleContours.length < expectedTotal) {
    throw Exception(
      'Apenas ${bubbleContours.length} bolhas detectadas; '
      'esperado $expectedTotal. '
      'Verifique iluminação, foco e o alinhamento da folha.',
    );
  }

  // =========================================================================
  // ETAPA 4: AGRUPAMENTO POR LINHA (FIX 5 – não usa blocos sequenciais)
  // =========================================================================
  // Ordena por Y crescente para facilitar o agrupamento
  bubbleContours.sort(
    (a, b) => cv.boundingRect(a).y.compareTo(cv.boundingRect(b).y),
  );

  // Tolerância dinâmica baseada na altura média das bolhas
  final avgH =
      bubbleContours
          .map((c) => cv.boundingRect(c).height.toDouble())
          .reduce((a, b) => a + b) /
      bubbleContours.length;
  final rowTolerance = avgH * 0.6;

  // Agrupa contornos em linhas pelo centro Y
  final List<List<cv.VecPoint>> rows = [];
  var currentRow = [bubbleContours.first];

  for (int i = 1; i < bubbleContours.length; i++) {
    final cY =
        cv.boundingRect(bubbleContours[i]).y +
        cv.boundingRect(bubbleContours[i]).height / 2;
    final rowY =
        cv.boundingRect(currentRow.first).y +
        cv.boundingRect(currentRow.first).height / 2;

    if ((cY - rowY).abs() < rowTolerance) {
      currentRow.add(bubbleContours[i]);
    } else {
      rows.add(List.from(currentRow));
      currentRow = [bubbleContours[i]];
    }
  }
  rows.add(currentRow);

  // Descarta linhas com número errado de bolhas
  final validRows = rows
      .where((r) => r.length == exam.availableOptions.length)
      .toList();

  if (validRows.length < exam.numQuestions) {
    throw Exception(
      'Apenas ${validRows.length} linhas válidas detectadas; '
      'esperado ${exam.numQuestions}.',
    );
  }

  // =========================================================================
  // ETAPA 5: LEITURA DE CADA QUESTÃO
  // =========================================================================
  final List<String?> answers = [];

  for (int q = 0; q < exam.numQuestions; q++) {
    final row = validRows[q];

    // Ordena as bolhas da esquerda para a direita dentro da linha
    row.sort((a, b) => cv.boundingRect(a).x.compareTo(cv.boundingRect(b).x));

    final List<double> fillRatios = [];

    for (final contour in row) {
      final mask = cv.Mat.zeros(
        wThresh.rows,
        wThresh.cols,
        cv.MatType.CV_8UC1,
      );
      cv.drawContours(
        mask,
        cv.VecVecPoint.fromVecPoint(contour),
        -1,
        cv.Scalar.all(255),
        thickness: -1,
      );

      // FIX 6 – fill ratio correto: pixels marcados / pixels totais da bolha
      final totalPx = cv.countNonZero(mask);
      final masked = cv.bitwiseAND(wThresh, wThresh, mask: mask);
      final filledPx = cv.countNonZero(masked);

      fillRatios.add(totalPx > 0 ? filledPx / totalPx : 0.0);
    }

    // Encontra o índice com maior fill ratio
    int bestIdx = 0;
    for (int j = 1; j < fillRatios.length; j++) {
      if (fillRatios[j] > fillRatios[bestIdx]) bestIdx = j;
    }

    // FIX 7 – limiar absoluto mínimo + vantagem mínima sobre a segunda melhor
    //   • limiar absoluto: bolha marcada com caneta/lápis tende a ter > 40 %
    //   • vantagem mínima: evita anular por ruído uniforme
    const double minAbsoluteThreshold = 0.40;
    const double minAdvantage = 0.15;

    final secondBest = fillRatios
        .asMap()
        .entries
        .where((e) => e.key != bestIdx)
        .map((e) => e.value)
        .fold(0.0, (max, v) => v > max ? v : max);

    if (fillRatios[bestIdx] >= minAbsoluteThreshold &&
        fillRatios[bestIdx] - secondBest >= minAdvantage) {
      answers.add(exam.availableOptions[bestIdx]);
    } else {
      answers.add(null); // em branco ou ambígua
    }
  }

  // Garante tamanho correto
  while (answers.length < exam.numQuestions) {
    answers.add(null);
  }
  return answers.sublist(0, exam.numQuestions);
}

// =============================================================================
// CORREÇÃO DE PERSPECTIVA – isolado para poder fazer try/catch no chamador
// =============================================================================
cv.Mat _attemptPerspectiveCorrection(cv.Mat image, cv.Mat opening) {
  final contours = cv
      .findContours(
        opening,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      )
      .$1;

  if (contours.isEmpty) throw Exception('sem contornos');

  cv.VecPoint? largest;
  double maxArea = 0;
  for (final c in contours) {
    final a = cv.contourArea(c);
    if (a > maxArea) {
      maxArea = a;
      largest = c;
    }
  }
  if (largest == null) throw Exception('contorno nulo');

  // Exige que a folha ocupe pelo menos 20 % da imagem para evitar
  // detectar um detalhe pequeno como sendo a folha inteira
  final minSheetArea = image.width * image.height * 0.20;
  if (maxArea < minSheetArea) throw Exception('contorno muito pequeno');

  final peri = cv.arcLength(largest, true);
  final approx = cv.approxPolyDP(largest, 0.02 * peri, true);

  // FIX 8 – aceita 4 OU 5 pontos (foto levemente curvada) — usa só os 4 extremos
  if (approx.length < 4) throw Exception('menos de 4 cantos');

  final pts = <cv.Point>[];
  for (int i = 0; i < approx.length; i++) {
    pts.add(approx[i]);
  }

  // Se mais de 4 pontos, reduz para os 4 extremos pelo bounding box
  final used = pts.length == 4 ? pts : _reduceTo4Points(pts);

  return _fourPointTransform(image, cv.VecPoint.fromList(used));
}

/// Reduz uma lista de pontos para os 4 cantos mais extremos
List<cv.Point> _reduceTo4Points(List<cv.Point> pts) {
  pts.sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
  final tl = pts.first;
  final br = pts.last;
  pts.sort((a, b) => (a.x - a.y).compareTo(b.x - b.y));
  final tr = pts.last;
  final bl = pts.first;
  return [tl, tr, br, bl];
}

// =============================================================================
// UTILITÁRIOS (inalterados)
// =============================================================================
cv.Mat _fourPointTransform(cv.Mat image, cv.VecPoint points) {
  final pts = <cv.Point>[];
  for (int i = 0; i < points.length; i++) {
    pts.add(points[i]);
  }

  final ordered = _orderPoints(pts);
  final tl = ordered[0], tr = ordered[1], br = ordered[2], bl = ordered[3];

  final maxWidth = math.max(_distance(br, bl), _distance(tr, tl)).toInt();
  final maxHeight = math.max(_distance(tr, br), _distance(tl, bl)).toInt();

  final src = cv.VecPoint2f.fromList([
    cv.Point2f(tl.x.toDouble(), tl.y.toDouble()),
    cv.Point2f(tr.x.toDouble(), tr.y.toDouble()),
    cv.Point2f(br.x.toDouble(), br.y.toDouble()),
    cv.Point2f(bl.x.toDouble(), bl.y.toDouble()),
  ]);
  final dst = cv.VecPoint2f.fromList([
    cv.Point2f(0, 0),
    cv.Point2f(maxWidth - 1, 0),
    cv.Point2f(maxWidth - 1, maxHeight - 1),
    cv.Point2f(0, maxHeight - 1),
  ]);

  final M = cv.getPerspectiveTransform2f(src, dst);
  return cv.warpPerspective(image, M, (maxWidth, maxHeight));
}

List<cv.Point> _orderPoints(List<cv.Point> points) {
  final ordered = List<cv.Point>.filled(4, cv.Point(0, 0));
  final sums = points.map((p) => p.x + p.y).toList();
  final diffs = points.map((p) => p.x - p.y).toList();

  int minS = 0, maxS = 0, minD = 0, maxD = 0;
  for (int i = 1; i < points.length; i++) {
    if (sums[i] < sums[minS]) minS = i;
    if (sums[i] > sums[maxS]) maxS = i;
    if (diffs[i] < diffs[minD]) minD = i;
    if (diffs[i] > diffs[maxD]) maxD = i;
  }
  ordered[0] = points[minS];
  ordered[1] = points[minD];
  ordered[2] = points[maxS];
  ordered[3] = points[maxD];
  return ordered;
}

double _distance(cv.Point p1, cv.Point p2) =>
    math.sqrt(math.pow(p2.x - p1.x, 2) + math.pow(p2.y - p1.y, 2));

ImageQualityResult validateImageQuality(File imageFile) {
  try {
    final kb = imageFile.lengthSync() / 1024;

    if (kb < 100) {
      return ImageQualityResult(
        isValid: false,
        message: 'Imagem muito pequena.',
      );
    }

    if (kb > 10240) {
      return ImageQualityResult(
        isValid: false,
        message: 'Imagem muito grande. Comprima antes de enviar.',
      );
    }

    return ImageQualityResult(isValid: true, message: 'Qualidade adequada.');
  } catch (e) {
    return ImageQualityResult(isValid: false, message: 'Erro ao validar: $e');
  }
}
