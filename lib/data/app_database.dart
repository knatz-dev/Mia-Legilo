import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Books, Shelves, Annotations, OutboxEntries, Conflicts, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await m.database.customStatement(
            'CREATE VIRTUAL TABLE IF NOT EXISTS books_fts USING fts5(book_id UNINDEXED, title, authors, series, description);',
          );
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS books_title_idx ON books (title);',
            );
            await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS books_added_at_idx ON books (added_at);',
            );
            await m.database.customStatement(
              'CREATE VIRTUAL TABLE IF NOT EXISTS books_fts USING fts5(book_id UNINDEXED, title, authors, series, description);',
            );
            // Backfill FTS for any existing rows.
            final List<QueryRow> rows =
                await m.database.customSelect(
              'SELECT id, title, authors, series, description FROM books',
            ).get();
            for (final row in rows) {
              await m.database.customStatement(
                'INSERT INTO books_fts (book_id, title, authors, series, description) VALUES (?, ?, ?, ?, ?)',
                [
                  row.read<String>('id'),
                  row.read<String?>('title'),
                  row.read<String?>('authors'),
                  row.read<String?>('series'),
                  row.read<String?>('description'),
                ],
              );
            }
          }
          if (from < 3) {
            await m.database.customStatement(
              'ALTER TABLE books ADD COLUMN reading_status_manual INTEGER NOT NULL DEFAULT 0;',
            );
          }
        },
      );
}
