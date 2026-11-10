import 'package:benchmark_core/benchmark_core.dart';
import 'package:flutter/widgets.dart';

/// Benchmark seam shared by the hosted engines.
///
/// The lab does not hide an engine behind a widget-less controller. epub.js
/// and foliate-js are WebViews, and epub_rtl is a Flutter scrollable. Each
/// engine widget owns its platform view and reports locations through
/// [locationChanged]. Navigation and typography go through the same object
/// so tests can tell the engines apart via [capabilities].
abstract interface class ReaderEngine {
  String get engineId;
  String get engineVersion;
  EngineCapability get capabilities;
  Stream<ReadingLocation> get locationChanged;
  Future<void> open(String filePath, {ReadingLocation? initialLocation});
  Future<ReadingLocation?> getCurrentLocation();
  Future<void> navigate(ReadingLocation location);
  Future<void> setPreferences(ReaderPreferences preferences);
  Future<void> close();
  Widget buildView();
}

/// Differences the lab is required to keep visible.
class EngineCapability {
  const EngineCapability({
    required this.exposesEpubCfi,
    required this.exposesSpineIndex,
    required this.exposesElementOffset,
    required this.exposesPercentage,
    required this.scrollMode,
  });

  final bool exposesEpubCfi;
  final bool exposesSpineIndex;
  final bool exposesElementOffset;

  /// True when the engine reports a whole-book fraction. That fraction is
  /// approximate and is never a bookmark identity.
  final bool exposesPercentage;
  final String scrollMode;
}

const epubRtlCapability = EngineCapability(
  exposesEpubCfi: false,
  exposesSpineIndex: true,
  exposesElementOffset: true,
  exposesPercentage: false,
  scrollMode: 'single CustomScrollView across spine items',
);

const epubJsCapability = EngineCapability(
  exposesEpubCfi: true,
  exposesSpineIndex: false,
  exposesElementOffset: false,
  exposesPercentage: true,
  scrollMode: 'epub.js manager=continuous flow=scrolled; device behavior unconfirmed',
);

const foliateCapability = EngineCapability(
  exposesEpubCfi: true,
  exposesSpineIndex: false,
  exposesElementOffset: false,
  exposesPercentage: true,
  scrollMode: 'foliate-paginator flow=scrolled without no-continuous-scroll',
);

const readiumCapability = EngineCapability(
  exposesEpubCfi: false,
  exposesSpineIndex: false,
  exposesElementOffset: false,
  exposesPercentage: true,
  scrollMode: 'Readium vertical scroll is per resource; not hosted in this app',
);
