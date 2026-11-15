import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/domain/book.dart';
import 'package:mia_legilo/domain/ids.dart';
import 'package:mia_legilo/library/library_query.dart';

void main() {
  test('each author gets the book once; total books remain distinct', () {
    const books = <Book>[
      Book(id: BookId('a'), title: 'Shared', authors: ['Ada', 'Bea', 'Ada']),
      Book(id: BookId('b'), title: 'Unknown', authors: [' ']),
    ];
    final groups = Map.fromEntries(groupBooks(books, LibraryGroupBy.author));
    expect(groups.keys, ['Ada', 'Bea', 'Unknown author']);
    expect(groups['Ada'], [books.first]);
    expect(groups['Bea'], [books.first]);
    expect(groups['Unknown author'], [books.last]);
    expect(books.length, 2);
  });

  test('blank series is unassigned and grouping preserves result order', () {
    const books = <Book>[
      Book(id: BookId('z'), title: 'Z', series: ' '),
      Book(id: BookId('a'), title: 'A'),
    ];
    final groups = groupBooks(books, LibraryGroupBy.series);
    expect(groups.single.key, 'Unassigned');
    expect(groups.single.value, books);
  });
}
