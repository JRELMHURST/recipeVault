import 'package:flutter/material.dart';

class ResultsScreen extends StatelessWidget {
  final String ocrText;

  const ResultsScreen({super.key, required this.ocrText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Formatted Recipe')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(ocrText, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
