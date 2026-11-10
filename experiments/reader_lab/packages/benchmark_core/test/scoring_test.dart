import 'dart:io';

import 'package:benchmark_core/benchmark_core.dart';
import 'package:test/test.dart';

void main() {
  CheckResult hard(String id, CheckStatus status) => CheckResult(
        id: id,
        status: status,
        evidence: 'fixture',
        hardRequirement: true,
      );

  CategoryScore scored(String name, int? score) =>
      CategoryScore(name: name, score: score, evidence: 'fixture');

  EngineScorecard card(List<CheckResult> checks, {int? scrolling}) {
    return EngineScorecard(
      engineId: 'example',
      checks: checks,
      categories: [
        scored('continuousScrolling', scrolling),
        scored('positionAndBookmarks', 4),
        scored('renderingPerformance', 3),
        scored('epubCompatibility', 3),
        scored('integrationMaintenance', 3),
        scored('einkSuitability', 2),
      ],
    );
  }

  test('widget-only evidence does not produce a weighted score', () {
    final scorecard = card(
      [
        hard('AC-001', CheckStatus.widgetPass),
        hard('AC-002', CheckStatus.pass),
      ],
      scrolling: 4,
    );
    expect(scorecard.meetsAllHardRequirements, isFalse);
    expect(scorecard.weightedScore(), isNull);
  });

  test('a source-level failure does not produce a weighted score', () {
    final scorecard = card(
      [
        hard('AC-001', CheckStatus.sourceNoncompliant),
        hard('AC-002', CheckStatus.notTested),
      ],
    );
    expect(scorecard.weightedScore(), isNull);
  });

  test('all hard passes and scored categories produce a weighted score', () {
    final scorecard = card(
      [
        hard('AC-001', CheckStatus.pass),
        hard('AC-002', CheckStatus.pass),
      ],
      scrolling: 5,
    );
    final score = scorecard.weightedScore();
    expect(score, isNotNull);
    expect(score!, inInclusiveRange(0, 5));
  });

  test('measurement csv escapes commas and reloads', () async {
    final file = File(
      '${Directory.systemTemp.path}/reader-lab-measurements.csv',
    );
    if (file.existsSync()) file.deleteSync();
    final log = MeasurementLog(file);
    await log.append(
      Measurement(
        engine: 'epub_rtl',
        device: 'none',
        epub: 'EPUB-001',
        scenario: 'corpus-inventory',
        runId: 'inventory',
        name: 'size',
        value: '12',
        unit: 'byte',
        timestamp: DateTime.utc(2026, 11, 10),
        method: 'sha256 file length',
        notes: 'not a device benchmark, comma',
      ),
    );
    final reloaded = MeasurementLog(file);
    await reloaded.load();
    expect(reloaded.rows.single.notes, 'not a device benchmark, comma');
    expect(reloaded.rows.single.value, '12');
    file.deleteSync();
  });
}
