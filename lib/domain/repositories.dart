import 'ids.dart';
import 'book.dart';
import 'shelf.dart';
import 'annotation.dart';

/// Local book repository contract.
abstract class BookRepository {
  Future<Book?> findById(BookId id);
  Future<List<Book>> findAll();
  Future<void> upsert(Book book);
  Future<void> delete(BookId id);
}

/// Local shelf repository contract.
abstract class ShelfRepository {
  Future<List<Shelf>> findAll();
  Future<void> upsert(Shelf shelf);
  Future<void> delete(ShelfId id);
}

/// Local bookmark repository contract.
abstract class BookmarkRepository {
  Future<List<Bookmark>> findByBook(BookId bookId);
  Future<void> upsert(Bookmark bookmark);
  Future<void> delete(AnnotationId id);
}

/// Local annotation repository contract.
abstract class AnnotationRepository {
  Future<List<Annotation>> findByBook(BookId bookId);
  Future<void> upsert(Annotation annotation);
  Future<void> delete(AnnotationId id);
}
