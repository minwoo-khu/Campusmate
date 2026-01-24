import 'package:flutter/material.dart';
import 'app/root_shell.dart';

void main() {
  runApp(const CampusMateApp());
}

class CampusMateApp extends StatelessWidget {
  const CampusMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusMate',
      theme: ThemeData(useMaterial3: true),
      home: const RootShell(),
    );
  }
}
