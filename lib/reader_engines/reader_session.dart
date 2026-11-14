import 'dart:async';

import '../domain/domain.dart';

enum ReaderSessionState { idle, loading, ready, error }

/// Semantic progress calculation (LIB-013).
class SemanticProgress {
  const SemanticProgress({
    required this.chapterIndex,
    required this.chapterCount,
    required this.chapterFraction,
  });

  final int chapterIndex;
  final int chapterCount;
  final double chapterFraction; // 0..1 within chapter

  /// Whole-book fraction (0..1). Never auto-completes at 1.0.
  double get wholeBookFraction {
    if (chapterCount <= 0) return 0;
    final base = chapterIndex / chapterCount;
    final slice = 1 / chapterCount;
    return (base + slice * chapterFraction).clamp(0.0, 0.999);
  }

  /// Chapter-level percentage (0..100).
  double get chapterPercentage => (chapterFraction * 100).clamp(0.0, 100.0);

  /// Whole-book percentage (0..100), never 100.
  double get wholeBookPercentage => (wholeBookFraction * 100).clamp(0.0, 99.9);
}

/// Reader session state machine with debounced checkpointing.
class ReaderSession {
  ReaderSession({this.checkpointDelay = const Duration(milliseconds: 500)});

  final Duration checkpointDelay;
  ReaderSessionState _state = ReaderSessionState.idle;
  ReadingLocator? _locator;
  Timer? _checkpointTimer;
  final _stateController = StreamController<ReaderSessionState>.broadcast();
  final _locatorController = StreamController<ReadingLocator>.broadcast();

  ReaderSessionState get state => _state;
  ReadingLocator? get locator => _locator;

  Stream<ReaderSessionState> get onState => _stateController.stream;
  Stream<ReadingLocator> get onLocator => _locatorController.stream;

  void setLoading() {
    _state = ReaderSessionState.loading;
    _stateController.add(_state);
  }

  void setReady() {
    _state = ReaderSessionState.ready;
    _stateController.add(_state);
  }

  void setError() {
    _state = ReaderSessionState.error;
    _stateController.add(_state);
  }

  /// Update current locator with debounced checkpoint.
  void updateLocator(ReadingLocator locator) {
    _locator = locator;
    _locatorController.add(locator);
    _checkpointTimer?.cancel();
    _checkpointTimer = Timer(checkpointDelay, () {
      // checkpoint persisted by caller; here just marks ready.
      if (_state == ReaderSessionState.ready) {
        _stateController.add(_state);
      }
    });
  }

  /// Force immediate checkpoint (e.g., on background/exit).
  void checkpointNow() {
    _checkpointTimer?.cancel();
    if (_locator != null) {
      _locatorController.add(_locator!);
    }
  }

  Future<void> dispose() async {
    _checkpointTimer?.cancel();
    await _stateController.close();
    await _locatorController.close();
  }
}
