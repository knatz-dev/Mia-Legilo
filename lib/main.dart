import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: MiaLegiloApp()));
}

class MiaLegiloApp extends StatelessWidget {
  const MiaLegiloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mia Legilo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B4F3A)),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('Mia Legilo')),
      ),
    );
  }
}
