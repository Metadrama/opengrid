import 'package:flutter/material.dart';
import 'widgets/grid_viewport.dart';

void main() {
  runApp(const OpenGridApp());
}

class OpenGridApp extends StatelessWidget {
  const OpenGridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TSP Salesmen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      ),
      home: const Scaffold(
        body: GridViewport(),
      ),
    );
  }
}
