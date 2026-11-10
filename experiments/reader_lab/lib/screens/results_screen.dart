import 'package:flutter/material.dart';

/// Status recorded in this commit. This is not a live device dashboard.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Evidence status')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'No Android device benchmark has been recorded in this workspace. '
            'Rows below are the evidence state of this commit. A widget-test '
            'pass is not a physical-device pass. See results/benchmark-report.md.',
          ),
          SizedBox(height: 16),
          _StatusLine('epub_rtl F-001 / F-002', 'widget test, when it passes'),
          _StatusLine('epub_rtl device performance', 'not tested'),
          _StatusLine('flutter_epub_viewer continuous scroll', 'not tested'),
          _StatusLine('foliate-js continuous scroll', 'not tested'),
          _StatusLine('flutter_readium continuous scroll', 'source review only; device not tested'),
          _StatusLine('e-ink ghosting', 'not tested; no e-ink hardware'),
          _StatusLine('ADR-001', 'Deferred'),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.label, this.status);

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(status),
    );
  }
}
