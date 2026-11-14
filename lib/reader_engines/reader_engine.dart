import 'dart:async';

import '../domain/domain.dart';

/// Abstract reader engine interface. Foliate-js is the primary implementation.
abstract class ReaderEngine {
  /// Load an EPUB from a local file path or URL.
  Future<void> load(String source);

  /// Stream of semantic location changes.
  Stream<ReadingLocator> get onLocationChanged;

  /// Navigate to a locator.
  Future<void> goTo(ReadingLocator locator);

  /// Go to next page/section.
  Future<void> goNext();

  /// Go to previous page/section.
  Future<void> goPrev();

  /// Search in book.
  Future<void> search(String query);

  /// Add a bookmark at current location.
  Future<void> addBookmark();

  /// Apply typography settings.
  Future<void> setTypography({
    double? fontSize,
    double? lineHeight,
    double? margin,
  });

  /// Apply theme.
  Future<void> setTheme(String theme);

  /// Dispose resources.
  Future<void> dispose();
}

/// A typed bridge message between Dart and the JS renderer.
class BridgeMessage {
  const BridgeMessage({required this.type, this.payload});

  final String type;
  final Map<String, dynamic>? payload;

  factory BridgeMessage.fromJson(Map<String, dynamic> json) => BridgeMessage(
        type: json['type'] as String? ?? 'unknown',
        payload: json['payload'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'payload': payload,
      };
}
