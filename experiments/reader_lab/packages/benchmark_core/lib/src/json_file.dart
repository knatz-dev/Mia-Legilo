import 'dart:convert';
import 'dart:io';

/// Small JSON object store used by bookmarks and reading positions.
class JsonFile {
  JsonFile(this.file);

  final File file;

  Future<Map<String, Object?>> read() async {
    if (!file.existsSync()) return <String, Object?>{};
    final text = await file.readAsString();
    if (text.trim().isEmpty) return <String, Object?>{};
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw FormatException('Expected a JSON object in ${file.path}');
    }
    return decoded.cast<String, Object?>();
  }

  Future<void> write(Map<String, Object?> value) async {
    await file.parent.create(recursive: true);
    final encoded = const JsonEncoder.withIndent('  ').convert(value);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString('$encoded\n');
    await temporary.rename(file.path);
  }
}
