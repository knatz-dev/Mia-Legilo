import 'package:xml/xml.dart';

/// A book entry parsed from an OPDS Atom feed.
class OpdsBook {
  const OpdsBook({
    required this.title,
    required this.id,
    this.authors = const <String>[],
    this.summary,
    this.coverUrl,
    this.acquisitionUrl,
    this.navigationUrl,
    this.updated,
  });

  final String title;
  final String id;
  final List<String> authors;
  final String? summary;
  final String? coverUrl;
  final String? acquisitionUrl;
  final String? navigationUrl;
  final DateTime? updated;

  bool get isDownloadable => acquisitionUrl != null && acquisitionUrl!.isNotEmpty;
  bool get isNavigation => navigationUrl != null && navigationUrl!.isNotEmpty;
}

/// A navigation link in an OPDS feed.
class OpdsLink {
  const OpdsLink({required this.rel, required this.href, this.title});

  final String rel;
  final String href;
  final String? title;

  bool get isNext => rel == 'next';
  bool get isPrevious => rel == 'previous';
  bool get isStart => rel == 'start' || rel == 'self';
}

/// Parses OPDS Atom feeds into books and navigation links.
class OpdsParser {
  const OpdsParser();

  List<OpdsBook> parseBooks(String xml) {
    final XmlDocument doc = XmlDocument.parse(xml);
    final List<OpdsBook> books = <OpdsBook>[];
    for (final XmlElement entry in doc.findAllElements('entry')) {
      final String title = _text(entry, 'title') ?? 'Untitled';
      final String id = _text(entry, 'id') ?? title;
      final List<String> authors = entry
          .findElements('author')
          .map((XmlElement a) => _text(a, 'name') ?? '')
          .where((String s) => s.isNotEmpty)
          .toList();
      final String? summary = _text(entry, 'summary') ?? _text(entry, 'content');
      String? coverUrl;
      String? acquisitionUrl;
      String? navigationUrl;
      for (final XmlElement link in entry.findElements('link')) {
        final String rel = link.getAttribute('rel') ?? '';
        final String href = link.getAttribute('href') ?? '';
        if (href.isEmpty) continue;
        if (rel.contains('image') || rel.contains('thumbnail') || rel.contains('cover')) {
          coverUrl ??= href;
        }
        if (rel.contains('acquisition') || rel.contains('http://opds-spec.org/acquisition')) {
          acquisitionUrl ??= href;
        }
        if (rel.contains('subsection') || rel.contains('http://opds-spec.org/subsection') ||
            rel.contains('alternate')) {
          navigationUrl ??= href;
        }
      }
      // Fallback: any link with an epub-ish href.
      if (acquisitionUrl == null) {
        for (final XmlElement link in entry.findElements('link')) {
          final String href = link.getAttribute('href') ?? '';
          if (href.toLowerCase().endsWith('.epub')) {
            acquisitionUrl = href;
            break;
          }
        }
      }
      // Fallback navigation: if no acquisition, use the first subsection link.
      if (navigationUrl == null && acquisitionUrl == null) {
        for (final XmlElement link in entry.findElements('link')) {
          final String href = link.getAttribute('href') ?? '';
          if (href.isNotEmpty) {
            navigationUrl = href;
            break;
          }
        }
      }
      DateTime? updated;
      final String? updatedRaw = _text(entry, 'updated');
      if (updatedRaw != null) {
        updated = DateTime.tryParse(updatedRaw);
      }
      books.add(OpdsBook(
        title: title,
        id: id,
        authors: authors,
        summary: summary,
        coverUrl: coverUrl,
        acquisitionUrl: acquisitionUrl,
        navigationUrl: navigationUrl,
        updated: updated,
      ));
    }
    return books;
  }

  List<OpdsLink> parseLinks(String xml) {
    final XmlDocument doc = XmlDocument.parse(xml);
    final List<OpdsLink> links = <OpdsLink>[];
    // Feed-level links.
    final XmlElement feed = doc.rootElement;
    for (final XmlElement link in feed.findElements('link')) {
      final String rel = link.getAttribute('rel') ?? '';
      final String href = link.getAttribute('href') ?? '';
      if (href.isEmpty) continue;
      links.add(OpdsLink(
        rel: rel,
        href: href,
        title: link.getAttribute('title'),
      ));
    }
    return links;
  }

  String? _text(XmlElement parent, String tag) {
    final Iterable<XmlElement> els = parent.findElements(tag);
    if (els.isEmpty) return null;
    return els.first.innerText.trim();
  }
}
