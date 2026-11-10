import 'package:benchmark_core/benchmark_core.dart';
import 'package:flutter/material.dart';

import '../screens/home_screen.dart';

class ReaderLabApp extends StatelessWidget {
  const ReaderLabApp({
    super.key,
    required this.bookmarks,
    required this.positions,
    required this.manifest,
  });

  final BookmarkStore bookmarks;
  final PositionStore positions;
  final CorpusManifest manifest;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mia Legilo Reader Lab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E4A3D)),
        useMaterial3: true,
      ),
      home: HomeScreen(
        bookmarks: bookmarks,
        positions: positions,
        manifest: manifest,
      ),
    );
  }
}
