/// Abstraction over wall-clock time to enable deterministic tests.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

class FakeClock implements Clock {
  FakeClock([DateTime? initial]) : _now = initial ?? DateTime.utc(2026, 1, 1);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);

  void setNow(DateTime value) => _now = value;
}
