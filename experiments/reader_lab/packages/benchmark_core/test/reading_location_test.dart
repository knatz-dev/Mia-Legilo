import 'package:benchmark_core/benchmark_core.dart';
import 'package:test/test.dart';

void main() {
  test('location json round-trips and keeps native locator fields', () {
    const location = ReadingLocation(
      engineId: 'epub_rtl',
      precision: LocationPrecision.exact,
      spineIndex: 4,
      progress: 0.2,
      nativeLocator: {
        'spine': 4,
        'element': 2,
        'fraction': 0.15,
        'fractionRole': 'within-block layout hint',
      },
    );
    final restored = ReadingLocation.decode(location.encode());
    expect(restored, location);
    expect(restored.nativeLocator?['element'], 2);
  });

  test('percentage alone is not an anchor match', () {
    const left = ReadingLocation(
      engineId: 'flutter_epub_viewer',
      precision: LocationPrecision.approximate,
      progress: 0.5,
    );
    const right = ReadingLocation(
      engineId: 'flutter_epub_viewer',
      precision: LocationPrecision.approximate,
      progress: 0.5,
    );
    expect(left.sameAnchor(right), isFalse);
  });

  test('CFI matches exactly and ignores progress', () {
    const left = ReadingLocation(
      engineId: 'foliate_js',
      precision: LocationPrecision.exact,
      epubCfi: 'epubcfi(/6/4!/4/2/1:0)',
      progress: 0.1,
    );
    const right = ReadingLocation(
      engineId: 'foliate_js',
      precision: LocationPrecision.exact,
      epubCfi: 'epubcfi(/6/4!/4/2/1:0)',
      progress: 0.9,
    );
    expect(left.sameAnchor(right), isTrue);
  });

  test('an explicit anchorId matches without using progress', () {
    const left = ReadingLocation(
      engineId: 'flutter_readium',
      precision: LocationPrecision.exact,
      progress: 0.2,
      nativeLocator: {'anchorId': 'chap.xhtml|#p3|sentence', 'totalProgression': 0.2},
    );
    const right = ReadingLocation(
      engineId: 'flutter_readium',
      precision: LocationPrecision.exact,
      progress: 0.8,
      nativeLocator: {'anchorId': 'chap.xhtml|#p3|sentence', 'totalProgression': 0.8},
    );
    expect(left.sameAnchor(right), isTrue);
  });

  test('epub_rtl identity is spine plus element, not fraction', () {
    const left = ReadingLocation(
      engineId: 'epub_rtl',
      precision: LocationPrecision.exact,
      spineIndex: 3,
      nativeLocator: {'element': 1, 'fraction': 0.1},
    );
    const sameBlock = ReadingLocation(
      engineId: 'epub_rtl',
      precision: LocationPrecision.exact,
      spineIndex: 3,
      nativeLocator: {'element': 1, 'fraction': 0.8},
    );
    const nextBlock = ReadingLocation(
      engineId: 'epub_rtl',
      precision: LocationPrecision.exact,
      spineIndex: 3,
      nativeLocator: {'element': 2, 'fraction': 0.1},
    );
    expect(left.sameAnchor(sameBlock), isTrue);
    expect(left.sameAnchor(nextBlock), isFalse);
  });
}
