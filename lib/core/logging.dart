/// Minimal redacting logger. Never log secrets, tokens, passwords, or PII.
class RedactingLogger {
  const RedactingLogger();

  static final RegExp _secretPattern = RegExp(
    r'(password|token|secret|authorization|cookie)\s*[:=]\s*\S+',
    caseSensitive: false,
  );

  String redact(String message) {
    return message.replaceAllMapped(_secretPattern, (m) => '${m.group(1)}: [REDACTED]');
  }

  void info(String message) => _print('INFO', redact(message));
  void warn(String message) => _print('WARN', redact(message));
  void error(String message) => _print('ERROR', redact(message));

  void _print(String level, String message) {
    // ignore: avoid_print
    print('[$level] $message');
  }
}
