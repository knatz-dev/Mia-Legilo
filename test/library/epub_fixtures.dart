import 'dart:typed_data';

import 'package:archive/archive.dart';

const String defaultContainer = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';

String standardOpf({
  String title = 'A Test Book',
  String creator = 'Test Author',
  String seriesMeta = '',
  String description = '',
  String coverItem = '',
  String extraManifest = '',
  int spineItems = 1,
  String version = '3.0',
}) =>
    '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="$version" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>$title</dc:title>
    <dc:creator>$creator</dc:creator>
    <dc:identifier id="uid">urn:uuid:test</dc:identifier>
    <dc:language>en</dc:language>
    ${description.isEmpty ? '' : '<dc:description>$description</dc:description>'}
    $seriesMeta
  </metadata>
  <manifest>
    <item id="chapter" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
    $extraManifest
    $coverItem
  </manifest>
  <spine>
    ${List<String>.generate(spineItems, (int i) => '<itemref idref="chapter"/>').join('\n    ')}
  </spine>
</package>
''';

/// Builds a minimal EPUB archive for tests.
Uint8List buildEpub({
  String mimetype = 'application/epub+zip',
  String container = defaultContainer,
  String packagePath = 'OEBPS/content.opf',
  String? opf,
  Map<String, List<int>> files = const <String, List<int>>{},
  bool includeContainer = true,
  bool includePackage = true,
  Map<String, List<int>> extraFirst = const <String, List<int>>{},
}) {
  final Archive archive = Archive();
  archive.add(ArchiveFile.bytes('mimetype', Uint8List.fromList(mimetype.codeUnits)));
  extraFirst.forEach((String path, List<int> bytes) {
    archive.add(ArchiveFile.bytes(path, Uint8List.fromList(bytes)));
  });
  if (includeContainer) {
    archive.add(ArchiveFile.string('META-INF/container.xml', container));
  }
  if (includePackage) {
    archive.add(ArchiveFile.string(packagePath, opf ?? standardOpf()));
  }
  files.forEach((String path, List<int> bytes) {
    archive.add(ArchiveFile.bytes(path, Uint8List.fromList(bytes)));
  });
  final List<int> encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}
