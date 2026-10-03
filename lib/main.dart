import 'package:flutter/material.dart';

void main() {
  runApp(const VmesteApp());
}

class VmesteApp extends StatelessWidget {
  const VmesteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Вместе',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8FAB)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вместе'),
        backgroundColor: const Color(0xFFFF8FAB),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, size: 80, color: Color(0xFFFF8FAB)),
            SizedBox(height: 24),
            Text(
              'Вместе',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Flutter-версия работает!',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Готово к переносу функционала',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}