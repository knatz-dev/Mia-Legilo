import 'dart:io';

/// One row of `results/measurements.csv`.
///
/// Values are recorded only when a run actually produced them. The writer
/// does not invent missing samples.
class Measurement {
  const Measurement({
    required this.engine,
    required this.device,
    required this.epub,
    required this.scenario,
    required this.runId,
    required this.name,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.method,
    this.notes = '',
  });

  final String engine;
  final String device;
  final String epub;
  final String scenario;
  final String runId;
  final String name;
  final String value;
  final String unit;
  final DateTime timestamp;
  final String method;
  final String notes;

  static const header = 'engine,device,epub,scenario,run_id,measurement,value,'
      'unit,timestamp,method,notes';

  String toCsv() => [
        engine,
        device,
        epub,
        scenario,
        runId,
        name,
        value,
        unit,
        timestamp.toUtc().toIso8601String(),
        method,
        notes,
      ].map(_escape).join(',');

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

class MeasurementLog {
  MeasurementLog(this.file);

  final File file;
  final List<Measurement> rows = [];

  Future<void> load() async {
    rows.clear();
    if (!file.existsSync()) return;
    final lines = await file.readAsLines();
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cells = _split(line);
      if (cells.length < 10) continue;
      rows.add(
        Measurement(
          engine: cells[0],
          device: cells[1],
          epub: cells[2],
          scenario: cells[3],
          runId: cells[4],
          name: cells[5],
          value: cells[6],
          unit: cells[7],
          timestamp: DateTime.parse(cells[8]),
          method: cells[9],
          notes: cells.length > 10 ? cells[10] : '',
        ),
      );
    }
  }

  Future<void> append(Measurement measurement) async {
    rows.add(measurement);
    await file.parent.create(recursive: true);
    final exists = file.existsSync() && await file.length() > 0;
    final sink = file.openWrite(mode: FileMode.writeOnlyAppend);
    if (!exists) {
      sink.writeln(Measurement.header);
    }
    sink.writeln(measurement.toCsv());
    await sink.flush();
    await sink.close();
  }

  static List<String> _split(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (quoted) {
        if (char == '"') {
          final escaped = i + 1 < line.length && line[i + 1] == '"';
          if (escaped) {
            buffer.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          buffer.write(char);
        }
      } else if (char == '"') {
        quoted = true;
      } else if (char == ',') {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString());
    return cells;
  }
}
