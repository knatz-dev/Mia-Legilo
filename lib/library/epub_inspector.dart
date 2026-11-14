import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// Metadata read from an EPUB package document (OPF).
class EpubMetadata {
  const EpubMetadata({
    required this.title,
    required this.authors,
    required this.spineCount,
    this.series,
    this.seriesIndex,
    this.description,
    this.identifier,
    this.language,
    this.coverBytes,
    this.coverMediaType,
  });

  final String title;
  final List<String> authors;
  final int spineCount;
  final String? series;
  final double? seriesIndex;
  final String? description;
  final String? identifier;
  final String? language;
  final Uint8List? coverBytes;
  final String? coverMediaType;

  /// File extension (with dot) for the cover image, if one was found.
  String? get coverExtension {
    final String? type = coverMediaType?.toLowerCase();
    return switch (type) {
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'image/gif' => '.gif',
      'image/webp' => '.webp',
      'image/svg+xml' => '.svg',
      _ => null,
    };
  }
}

/// Rejection reasons for an EPUB that must not enter the library.
enum EpubRejection {
  notAZipArchive,
  archiveTooLarge,
  unsafeEntryName,
  missingMimetype,
  wrongMimetype,
  missingContainer,
  missingPackageDocument,
  packageDocumentTooLarge,
  drmProtected,
  emptySpine,
  malformedMetadata,
}

class EpubValidationException implements Exception {
  const EpubValidationException(this.reason, this.message);

  final EpubRejection reason;
  final String message;

  @override
  String toString() => 'EpubValidationException(${reason.name}): $message';
}

/// Validates EPUB archives and reads their bibliographic metadata.
///
/// The inspector never extracts to disk. It reads the ZIP directory first to
/// reject zip bombs (entry count and declared uncompressed size) and unsafe
/// entry names, then decompresses only `mimetype`, the container, the package
/// document and the cover image subject to individual size caps.
class EpubInspector {
  const EpubInspector();

  static const String _mimetype = 'application/epub+zip';
  static const int maxArchiveBytes = 512 * 1024 * 1024;
  static const int maxEntries = 20000;
  static const int maxUncompressedBytes = 2 * 1024 * 1024 * 1024;
  static const int maxPackageDocumentBytes = 4 * 1024 * 1024;
  static const int maxContainerBytes = 256 * 1024;
  static const int maxCoverBytes = 16 * 1024 * 1024;

  /// Font obfuscation algorithms are permitted; anything else means DRM.
  static const Set<String> _allowedEncryptionAlgorithms = <String>{
    'http://www.idpf.org/2008/embedding',
    'http://ns.adobe.com/pdf/enc#RC',
  };

  EpubMetadata inspectBytes(Uint8List bytes) {
    if (bytes.length > maxArchiveBytes) {
      throw const EpubValidationException(
        EpubRejection.archiveTooLarge,
        'The file is larger than the 512 MB import limit.',
      );
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (e) {
      throw EpubValidationException(
        EpubRejection.notAZipArchive,
        'The file is not a readable ZIP archive ($e).',
      );
    }

    _validateArchiveShape(archive);
    _validateMimetype(archive);

    final ArchiveFile container = _requireEntry(archive, 'META-INF/container.xml');
    final String containerXml = _decodeRootFile(container, maxContainerBytes,
        EpubRejection.missingContainer);
    final String? packagePath = _packagePath(containerXml);
    if (packagePath == null) {
      throw const EpubValidationException(
        EpubRejection.missingContainer,
        'META-INF/container.xml does not reference a package document.',
      );
    }

    final ArchiveFile package = _requireEntry(archive, packagePath);
    if (package.size > maxPackageDocumentBytes) {
      throw const EpubValidationException(
        EpubRejection.packageDocumentTooLarge,
        'The package document is larger than 4 MB.',
      );
    }
    final XmlDocument opf;
    try {
      opf = XmlDocument.parse(_decodeRootFile(package, maxPackageDocumentBytes,
          EpubRejection.missingPackageDocument));
    } catch (e) {
      throw EpubValidationException(
        EpubRejection.malformedMetadata,
        'The package document is not valid XML ($e).',
      );
    }

    _rejectDrm(archive);
    final _PackageInfo info = _readPackage(opf, packagePath, archive);
    if (info.spineCount == 0) {
      throw const EpubValidationException(
        EpubRejection.emptySpine,
        'The EPUB declares no readable spine items.',
      );
    }

    return EpubMetadata(
      title: info.title,
      authors: info.authors,
      series: info.series,
      seriesIndex: info.seriesIndex,
      description: info.description,
      identifier: info.identifier,
      language: info.language,
      spineCount: info.spineCount,
      coverBytes: info.coverBytes,
      coverMediaType: info.coverMediaType,
    );
  }

  void _validateArchiveShape(Archive archive) {
    int entries = 0;
    int uncompressed = 0;
    for (final ArchiveFile file in archive) {
      entries++;
      if (entries > maxEntries) {
        throw const EpubValidationException(
          EpubRejection.archiveTooLarge,
          'The archive has more than 20,000 entries.',
        );
      }
      uncompressed += file.size;
      if (uncompressed > maxUncompressedBytes) {
        throw const EpubValidationException(
          EpubRejection.archiveTooLarge,
          'The archive expands beyond the 2 GB safety limit.',
        );
      }
      final String name = file.name;
      if (name.startsWith('/') ||
          name.startsWith(r'\') ||
          RegExp(r'(^|[\\/])\.\.([\\/]|$)').hasMatch(name)) {
        throw EpubValidationException(
          EpubRejection.unsafeEntryName,
          'The archive contains an unsafe path: $name',
        );
      }
    }
  }

  void _validateMimetype(Archive archive) {
    final ArchiveFile? mimetype = _findEntry(archive, 'mimetype');
    if (mimetype == null) {
      throw const EpubValidationException(
        EpubRejection.missingMimetype,
        'The archive has no mimetype entry.',
      );
    }
    if (mimetype.size > 128) {
      throw const EpubValidationException(
        EpubRejection.wrongMimetype,
        'The mimetype entry is implausibly large.',
      );
    }
    final String value = utf8.decode(mimetype.content, allowMalformed: true).trim();
    if (value != _mimetype) {
      throw EpubValidationException(
        EpubRejection.wrongMimetype,
        'The mimetype entry is "$value", expected "$_mimetype".',
      );
    }
  }

  void _rejectDrm(Archive archive) {
    final ArchiveFile? encryption = _findEntry(archive, 'META-INF/encryption.xml');
    if (encryption == null) return;
    if (encryption.size > maxContainerBytes) {
      throw const EpubValidationException(
        EpubRejection.drmProtected,
        'META-INF/encryption.xml is larger than expected.',
      );
    }
    final XmlDocument document;
    try {
      document = XmlDocument.parse(utf8.decode(encryption.content, allowMalformed: true));
    } catch (_) {
      throw const EpubValidationException(
        EpubRejection.drmProtected,
        'META-INF/encryption.xml is unreadable, which usually means DRM.',
      );
    }
    for (final XmlElement element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'EncryptionMethod') continue;
      final String? algorithm = element.getAttribute('Algorithm');
      if (algorithm != null && !_allowedEncryptionAlgorithms.contains(algorithm)) {
        throw EpubValidationException(
          EpubRejection.drmProtected,
          'The EPUB uses an unsupported encryption method ($algorithm).',
        );
      }
    }
  }

  _PackageInfo _readPackage(XmlDocument opf, String packagePath, Archive archive) {
    final Iterable<XmlElement> elements =
        opf.descendants.whereType<XmlElement>();
    final String baseDir = p.url.dirname(packagePath);

    String? title;
    final List<String> authors = <String>[];
    String? description;
    String? identifier;
    String? language;
    String? series;
    double? seriesIndex;

    for (final XmlElement element in elements) {
      switch (element.name.local) {
        case 'title':
          title ??= _cleanText(element.innerText);
        case 'creator':
          final String name = _cleanText(element.innerText);
          if (name.isNotEmpty && !authors.contains(name)) authors.add(name);
        case 'description':
          description ??= _stripMarkup(element.innerText);
        case 'identifier':
          identifier ??= _cleanText(element.innerText);
        case 'language':
          language ??= _cleanText(element.innerText);
      }
    }

    // EPUB 3 collections (belongs-to-collection + group-position) and the
    // EPUB 2 Calibre metadata convention both describe series.
    final Map<String, String> collectionNames = <String, String>{};
    final Map<String, String> collectionPositions = <String, String>{};
    final String? calibreSeries =
        _metaContent(elements, 'name', 'calibre:series', byName: true);
    final String? calibreIndex =
        _metaContent(elements, 'name', 'calibre:series_index', byName: true);

    for (final XmlElement element in elements) {
      if (element.name.local != 'meta') continue;
      final String? property = element.getAttribute('property');
      if (property == null) continue;
      final String? id = element.getAttribute('id');
      if (property == 'belongs-to-collection' && id != null) {
        final String name = _cleanText(element.innerText);
        if (name.isNotEmpty) collectionNames[id] = name;
      } else if (property == 'group-position' && id != null) {
        collectionPositions[id] = _cleanText(element.innerText);
      }
    }

    String? positionText;
    for (final XmlElement element in elements) {
      if (element.name.local != 'meta') continue;
      if (element.getAttribute('property') != 'group-position') continue;
      final String? refines = element.getAttribute('refines');
      if (refines == null) continue;
      final String referenced = refines.startsWith('#') ? refines.substring(1) : refines;
      if (collectionNames.containsKey(referenced)) {
        series = collectionNames[referenced];
        positionText = _cleanText(element.innerText);
        break;
      }
    }
    series ??= collectionNames.values.isEmpty ? null : collectionNames.values.first;
    positionText ??= calibreIndex;
    series ??= (calibreSeries == null || calibreSeries.trim().isEmpty)
        ? null
        : calibreSeries.trim();
    seriesIndex = _parseIndex(positionText);

    // Manifest + spine.
    final List<XmlElement> manifestItems = elements
        .where((XmlElement e) => e.name.local == 'item')
        .toList(growable: false);
    final int spineCount = elements
        .where((XmlElement e) => e.name.local == 'itemref')
        .length;

    // Cover: EPUB 3 `properties="cover-image"` first, then EPUB 2
    // `<meta name="cover" content="id"/>`, then a manifest id named "cover".
    XmlElement? coverItem;
    for (final XmlElement item in manifestItems) {
      final String properties = item.getAttribute('properties') ?? '';
      if (properties.split(RegExp(r'\s+')).contains('cover-image')) {
        coverItem = item;
        break;
      }
    }
    if (coverItem == null) {
      final String? coverId =
          _metaContent(elements, 'name', 'cover', byName: true);
      if (coverId != null) {
        for (final XmlElement item in manifestItems) {
          if (item.getAttribute('id') == coverId) {
            coverItem = item;
            break;
          }
        }
      }
    }
    if (coverItem == null) {
      for (final XmlElement item in manifestItems) {
        if ((item.getAttribute('id') ?? '') == 'cover') {
          coverItem = item;
          break;
        }
      }
    }

    Uint8List? coverBytes;
    String? coverMediaType;
    if (coverItem != null) {
      final String? href = coverItem.getAttribute('href');
      final String type = (coverItem.getAttribute('media-type') ?? '').toLowerCase();
      if (href != null && type.startsWith('image/')) {
        final String coverPath = _resolveHref(baseDir, href);
        final ArchiveFile? file = _findEntry(archive, coverPath);
        if (file != null && file.size <= maxCoverBytes) {
          coverBytes = file.content;
          coverMediaType = type;
        }
      }
    }

    return _PackageInfo(
      title: title ?? '',
      authors: authors,
      description: description,
      identifier: identifier,
      language: language,
      series: series,
      seriesIndex: seriesIndex,
      spineCount: spineCount,
      coverBytes: coverBytes,
      coverMediaType: coverMediaType,
    );
  }

  String? _metaContent(
    Iterable<XmlElement> elements,
    String attribute,
    String value, {
    required bool byName,
  }) {
    for (final XmlElement element in elements) {
      if (element.name.local != 'meta') continue;
      if (element.getAttribute(attribute) != value) continue;
      if (byName) {
        final String? content = element.getAttribute('content');
        if (content != null && content.trim().isNotEmpty) return content.trim();
      } else {
        return _cleanText(element.innerText);
      }
    }
    return null;
  }

  ArchiveFile? _findEntry(Archive archive, String name) {
    final String normalized = name.replaceAll(r'\', '/');
    for (final ArchiveFile file in archive) {
      if (file.name.replaceAll(r'\', '/') == normalized) return file;
    }
    // Some producers percent-encode hrefs; compare decoded forms as a last
    // resort without loosening the path-traversal checks above.
    for (final ArchiveFile file in archive) {
      if (Uri.decodeComponent(file.name.replaceAll(r'\', '/')) ==
          Uri.decodeComponent(normalized)) {
        return file;
      }
    }
    return null;
  }

  ArchiveFile _requireEntry(Archive archive, String name) {
    final ArchiveFile? file = _findEntry(archive, name);
    if (file == null) {
      throw EpubValidationException(
        name.endsWith('container.xml')
            ? EpubRejection.missingContainer
            : EpubRejection.missingPackageDocument,
        'The archive is missing $name.',
      );
    }
    return file;
  }

  String _decodeRootFile(ArchiveFile file, int maxBytes, EpubRejection reason) {
    if (file.size > maxBytes) {
      throw EpubValidationException(
        reason,
        '${file.name} is larger than the ${maxBytes ~/ 1024} KB limit.',
      );
    }
    return utf8.decode(file.content, allowMalformed: true);
  }

  String? _packagePath(String containerXml) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(containerXml);
    } catch (e) {
      throw EpubValidationException(
        EpubRejection.missingContainer,
        'META-INF/container.xml is not valid XML ($e).',
      );
    }
    for (final XmlElement element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'rootfile') continue;
      final String? path = element.getAttribute('full-path');
      if (path != null && path.trim().isNotEmpty) {
        return Uri.decodeFull(path.trim()).replaceAll(r'\', '/');
      }
    }
    return null;
  }

  String _resolveHref(String baseDir, String href) {
    final String decoded = Uri.decodeFull(href).replaceAll(r'\', '/');
    final String joined = baseDir == '.' || baseDir.isEmpty
        ? decoded
        : p.url.join(baseDir, decoded);
    return p.url.normalize(joined);
  }

  double? _parseIndex(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final double? direct = double.tryParse(trimmed);
    if (direct != null) return direct;
    // Accept "Book 2", "2 of 5" and similar prose.
    final RegExpMatch? match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(trimmed);
    if (match == null) return null;
    return double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }

  String _cleanText(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  String _stripMarkup(String value) {
    final String withoutTags = value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return _cleanText(withoutTags);
  }
}

class _PackageInfo {
  const _PackageInfo({
    required this.title,
    required this.authors,
    required this.spineCount,
    this.series,
    this.seriesIndex,
    this.description,
    this.identifier,
    this.language,
    this.coverBytes,
    this.coverMediaType,
  });

  final String title;
  final List<String> authors;
  final int spineCount;
  final String? series;
  final double? seriesIndex;
  final String? description;
  final String? identifier;
  final String? language;
  final Uint8List? coverBytes;
  final String? coverMediaType;
}
