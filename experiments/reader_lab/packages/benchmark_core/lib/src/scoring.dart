/// Evidence status for one functional or performance check.
///
/// [pass] is reserved for a completed check on the target Android hardware.
/// [widgetPass] is an automated Flutter widget-test result and does not by
/// itself satisfy a hard acceptance criterion.
enum CheckStatus {
  pass,
  widgetPass,
  fail,
  blocked,
  notTested,
  sourceNoncompliant,
}

/// One acceptance check.
class CheckResult {
  const CheckResult({
    required this.id,
    required this.status,
    required this.evidence,
    this.hardRequirement = false,
  });

  final String id;
  final CheckStatus status;
  final String evidence;
  final bool hardRequirement;

  bool get countsAsSatisfied => status == CheckStatus.pass;
}

/// Category score. Null when the category was not measured.
class CategoryScore {
  const CategoryScore({required this.name, required this.score, required this.evidence});

  /// 0..5, or null when there is no evidence to score.
  final String name;
  final int? score;
  final String evidence;
}

class EngineScorecard {
  const EngineScorecard({
    required this.engineId,
    required this.checks,
    required this.categories,
  });

  final String engineId;
  final List<CheckResult> checks;
  final List<CategoryScore> categories;

  bool get meetsAllHardRequirements => checks
      .where((check) => check.hardRequirement)
      .every((check) => check.countsAsSatisfied);

  /// Weighted score in 0..5. Null unless every hard requirement has a
  /// device [CheckStatus.pass] and every weighted category has a score.
  double? weightedScore({
    Map<String, double> weights = defaultWeights,
  }) {
    if (!meetsAllHardRequirements) return null;
    var total = 0.0;
    var weightSum = 0.0;
    for (final category in categories) {
      final weight = weights[category.name];
      final score = category.score;
      if (weight == null || score == null) return null;
      total += weight * score;
      weightSum += weight;
    }
    if (weightSum == 0) return null;
    return total / weightSum;
  }

  static const defaultWeights = {
    'continuousScrolling': 0.35,
    'positionAndBookmarks': 0.25,
    'renderingPerformance': 0.15,
    'epubCompatibility': 0.10,
    'integrationMaintenance': 0.10,
    'einkSuitability': 0.05,
  };
}
