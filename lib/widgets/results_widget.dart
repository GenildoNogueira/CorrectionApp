import 'package:flutter/material.dart';

import '../models/exam.dart';

class ResultsWidget extends StatelessWidget {
  final ExamResult result;
  final int totalQuestions;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;

  const ResultsWidget({
    super.key,
    required this.result,
    required this.totalQuestions,
    required this.fadeAnimation,
    required this.slideAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              SizedBox(height: 25),
              _buildStatsRow(),
              SizedBox(height: 20),
              _buildPerformanceIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Center(
            child: Text(
              _getPerformanceEmoji(),
              style: TextStyle(fontSize: 40),
            ),
          ),
        ),
        SizedBox(height: 15),
        Text(
          '${result.correctCount}/$totalQuestions',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          '${result.percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        SizedBox(height: 10),
        Text(
          _getPerformanceMessage(),
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      spacing: 15,
      children: [
        Expanded(
          child: _buildStatCard(
            'Acertos',
            result.correctCount.toString(),
            Icons.check_circle,
            Colors.green.shade300,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'Erros',
            result.wrongCount.toString(),
            Icons.cancel,
            Colors.red.shade300,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'Aproveitamento',
            '${result.percentage.toStringAsFixed(0)}%',
            Icons.trending_up,
            Colors.blue.shade300,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceIndicator() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        spacing: 10,
        children: [
          Text(
            'Desempenho Geral',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          LinearProgressIndicator(
            value: result.percentage / 100,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(_getPerformanceColor()),
            borderRadius: BorderRadius.all(Radius.circular(8)),
            minHeight: 8,
          ),
          Text(
            _getDetailedPerformanceMessage(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getPerformanceEmoji() {
    if (result.percentage >= 90) return '🏆';
    if (result.percentage >= 80) return '😊';
    if (result.percentage >= 70) return '🙂';
    if (result.percentage >= 60) return '😐';
    return '😔';
  }

  String _getPerformanceMessage() {
    if (result.percentage >= 90) return 'Excelente desempenho!';
    if (result.percentage >= 80) return 'Muito bom!';
    if (result.percentage >= 70) return 'Bom desempenho!';
    if (result.percentage >= 60) return 'Desempenho satisfatório';
    return 'Precisa melhorar';
  }

  String _getDetailedPerformanceMessage() {
    if (result.percentage >= 90) {
      return 'Parabéns! Você domina muito bem o conteúdo.';
    }
    if (result.percentage >= 80) return 'Ótimo resultado! Continue assim.';
    if (result.percentage >= 70) return 'Bom trabalho! Há espaço para crescer.';
    if (result.percentage >= 60) {
      return 'Resultado adequado. Revise alguns pontos.';
    }
    return 'Recomenda-se revisar o conteúdo e treinar mais.';
  }

  Color _getPerformanceColor() {
    if (result.percentage >= 80) return Colors.green.shade300;
    if (result.percentage >= 60) return Colors.yellow.shade300;
    return Colors.red.shade300;
  }
}
