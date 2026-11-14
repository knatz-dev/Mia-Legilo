import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/domain/domain.dart';
import 'package:mia_legilo/reader_engines/reader_session.dart';

void main() {
  group('SemanticProgress', () {
    test('whole-book fraction never reaches 1.0', () {
      const p = SemanticProgress(chapterIndex: 9, chapterCount: 10, chapterFraction: 1.0);
      expect(p.wholeBookFraction, lessThan(1.0));
      expect(p.wholeBookPercentage, lessThan(100.0));
    });
    test('chapter percentage', () {
      const p = SemanticProgress(chapterIndex: 0, chapterCount: 10, chapterFraction: 0.5);
      expect(p.chapterPercentage, 50.0);
    });
    test('first chapter fraction', () {
      const p = SemanticProgress(chapterIndex: 0, chapterCount: 4, chapterFraction: 0.25);
      expect(p.wholeBookFraction, closeTo(0.0625, 0.0001));
    });
  });

  group('ReaderSession', () {
    test('state transitions', () async {
      final s = ReaderSession();
      expect(s.state, ReaderSessionState.idle);
      s.setLoading();
      expect(s.state, ReaderSessionState.loading);
      s.setReady();
      expect(s.state, ReaderSessionState.ready);
      s.setError();
      expect(s.state, ReaderSessionState.error);
      await s.dispose();
    });

    test('updateLocator stores locator', () async {
      final s = ReaderSession();
      s.setReady();
      const loc = ReadingLocator(cfi: '/6/4');
      s.updateLocator(loc);
      expect(s.locator, equals(loc));
      await s.dispose();
    });
  });
}
