// Classe para estatísticas de performance
class PerformanceStats {
  int frameCount = 0;
  int processedFrames = 0;
  int skippedFrames = 0;
  double averageProcessingTime = 0;
  DateTime lastReset = DateTime.now();
  
  void recordFrame(int processingTimeMs) {
    frameCount++;
    processedFrames++;
    
    // Média móvel do tempo de processamento
    averageProcessingTime = (averageProcessingTime * (processedFrames - 1) + processingTimeMs) / processedFrames;
    
    // Reset estatísticas a cada minuto
    if (DateTime.now().difference(lastReset).inMinutes >= 1) {
      reset();
    }
  }
  
  void recordSkippedFrame() {
    frameCount++;
    skippedFrames++;
  }
  
  void reset() {
    frameCount = 0;
    processedFrames = 0;
    skippedFrames = 0;
    averageProcessingTime = 0;
    lastReset = DateTime.now();
  }
  
  double get processingRate => frameCount > 0 ? processedFrames / frameCount : 0;
  double get skipRate => frameCount > 0 ? skippedFrames / frameCount : 0;
}
