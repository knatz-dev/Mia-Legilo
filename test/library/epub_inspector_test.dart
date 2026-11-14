import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/library/epub_inspector.dart';

import 'epub_fixtures.dart';

void main() {
  const EpubInspector inspector = EpubInspector();

  group('EPUB validation', () {
    test('reads a real Gutenberg EPUB', () {
      final Uint8List bytes =
          File('test/fixtures/epub/84.epub').readAsBytesSync();
      final EpubMetadata metadata = inspector.inspectBytes(bytes);

      expect(metadata.title.toLowerCase(), contains('frankenstein'));
      expect(metadata.authors, isNotEmpty);
      expect(metadata.spineCount, greaterThan(0));
    });

    test('rejects non-ZIP bytes', () {
      expect(
        () => inspector.inspectBytes(Uint8List.fromList(<int>[1, 2, 3, 4])),
        throwsA(isA<EpubValidationException>().having(
          (EpubValidationException e) => e.reason,
          'reason',
          EpubRejection.notAZipArchive,
        )),
      );
    });

    test('rejects a ZIP without the EPUB mimetype', () {
      expect(
        () => inspector.inspectBytes(buildEpub(mimetype: 'application/zip')),
        throwsA(isA<EpubValidationException>().having(
          (EpubValidationException e) => e.reason,
          'reason',
          EpubRejection.wrongMimetype,
        )),
      );
    });

    test('rejects an archive without META-INF/container.xml', () {
      expect(
        () => inspector.inspectBytes(buildEpub(includeContainer: false)),
        throwsA(isA<EpubValidationException>().having(
          (EpubValidationException e) => e.reason,
          'reason',
          EpubRejection.missingContainer,
        )),
      );
    });

    test('rejects an archive without the package document', () {
      expect(
        () => inspector.inspectBytes(buildEpub(includePackage: false)),
        throwsA(isA<EpubValidationException>().having(
          (EpubValidationException e) => e.reason,
          'reason',
          EpubRejection.missingPackageDocument,
        )),
      );
    });

    test('rejects unsafe path traversal entries', () {
      expect(
        () => inspector.inspectBytes(buildEpub(
          extraFirst: <String, List<int>>{
            '../escape.txt': <int>[1, 2, 3],
          },
        )),
        throwsA(isA<EpubValidationException>().having(
          (EpubValidationException e) => e.reason,
          'reason',
          EpubRejection.unsafeEntryName,
        )),
      );
    });

    test('rejects an empty spine', () {
      expect(
        () => inspector.inspectBytes(
          buildEpub(opf: standardOpf(spineItems: 0)),
        ),
        throwsA(isA<EpubValidationException>().having(
          (EpubValidationException e) => e.reason,
          'reason',
          EpubRejection.emptySpine,
        )),
      );
    });

    test('rejects DRM-protected content', () {
      const String encryption = '''<?xml version="1.0"?>
<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container"
    xmlns:enc="http://www.w3.org/2001/04/xmlenc#">
  <enc:EncryptedData>
    <enc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes256-cbc"/>
  </enc:EncryptedData>
</encryption>
''';
      expect(
        () => inspector.inspectBytes(buildEpub(
          extraFirst: <String, List<int>>{
            'META-INF/encryption.xml': encryption.codeUnits,
          },
        )),
        throwsA(isA<EpubValidationException>().having(
          (EpubValidationException e) => e.reason,
          'reason',
          EpubRejection.drmProtected,
        )),
      );
    });

    test('allows font obfuscation', () {
      const String encryption = '''<?xml version="1.0"?>
<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container"
    xmlns:enc="http://www.w3.org/2001/04/xmlenc#">
  <enc:EncryptedData>
    <enc:EncryptionMethod Algorithm="http://www.idpf.org/2008/embedding"/>
  </enc:EncryptedData>
</encryption>
''';
      final EpubMetadata metadata = inspector.inspectBytes(buildEpub(
        extraFirst: <String, List<int>>{
          'META-INF/encryption.xml': encryption.codeUnits,
        },
      ));
      expect(metadata.title, 'A Test Book');
    });
  });

  group('metadata extraction', () {
    test('reads title, authors, language and spine count', () {
      final EpubMetadata metadata = inspector.inspectBytes(buildEpub(
        opf: standardOpf(title: 'The Deep Module', creator: 'Ada Lovelace'),
      ));

      expect(metadata.title, 'The Deep Module');
      expect(metadata.authors, <String>['Ada Lovelace']);
      expect(metadata.language, 'en');
      expect(metadata.spineCount, 1);
    });

    test('reads EPUB 3 series and group position', () {
      final EpubMetadata metadata = inspector.inspectBytes(buildEpub(
        opf: standardOpf(
          seriesMeta: '''
    <meta property="belongs-to-collection" id="s1">The Sequence</meta>
    <meta refines="#s1" property="collection-type">series</meta>
    <meta refines="#s1" property="group-position">3</meta>''',
        ),
      ));

      expect(metadata.series, 'The Sequence');
      expect(metadata.seriesIndex, 3);
    });

    test('reads Calibre series metadata', () {
      final EpubMetadata metadata = inspector.inspectBytes(buildEpub(
        opf: standardOpf(
          seriesMeta: '''
    <meta name="calibre:series" content="Old Series"/>
    <meta name="calibre:series_index" content="2.5"/>''',
          version: '2.0',
        ),
      ));

      expect(metadata.series, 'Old Series');
      expect(metadata.seriesIndex, 2.5);
    });

    test('strips markup from descriptions', () {
      final EpubMetadata metadata = inspector.inspectBytes(buildEpub(
        opf: standardOpf(description: '&lt;p&gt;A &lt;b&gt;good&lt;/b&gt; read&lt;/p&gt;'),
      ));

      expect(metadata.description, 'A good read');
    });

    test('extracts cover bytes and media type', () {
      final Uint8List cover = Uint8List.fromList(<int>[137, 80, 78, 71, 1, 2]);
      final EpubMetadata metadata = inspector.inspectBytes(buildEpub(
        opf: standardOpf(
          coverItem:
              '<item id="cover-img" href="images/cover.png" media-type="image/png" properties="cover-image"/>',
        ),
        files: <String, List<int>>{'OEBPS/images/cover.png': cover},
      ));

      expect(metadata.coverMediaType, 'image/png');
      expect(metadata.coverExtension, '.png');
      expect(metadata.coverBytes, cover);
    });
  });
}
