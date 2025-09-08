import 'package:flutter/material.dart';

import 'screens/correction_screen.dart';

void main() {
  runApp(CorrectionApp());
}

class CorrectionApp extends StatelessWidget {
  const CorrectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Corretor de Provas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ),
        fontFamily: 'Segoe UI',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarThemeData(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.blue,
        ),
        scaffoldBackgroundColor: Colors.blue,
      ),
      home: CorrectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
