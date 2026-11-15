import 'package:drift/drift.dart';

@TableIndex(name: 'books_title_idx', columns: {#title})
@TableIndex(name: 'books_added_at_idx', columns: {#addedAt})
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get authors => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get series => text().nullable()();
  RealColumn get seriesIndex => real().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  TextColumn get readingStatus => text().withDefault(const Constant('unread'))();
  BoolColumn get readingStatusManual => boolean().withDefault(const Constant(false))();
  TextColumn get locator => text().nullable()(); // JSON
  TextColumn get remoteProviderInstanceId => text().nullable()();
  TextColumn get remoteBookId => text().nullable()();
  TextColumn get downloadState => text().withDefault(const Constant('notDownloaded'))();
  TextColumn get localAssetPath => text().nullable()();
  TextColumn get localAssetSha256 => text().nullable()();
  IntColumn get localAssetRevision => integer().nullable()();
  TextColumn get shelfIds => text().withDefault(const Constant('[]'))(); // JSON array
  DateTimeColumn get addedAt => dateTime().nullable()();
  DateTimeColumn get lastReadAt => dateTime().nullable()();
  RealColumn get progressPercentage => real().nullable()();
  TextColumn get metadataProvenance => text().withDefault(const Constant('standard'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Shelves extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Annotations extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get locator => text()(); // JSON
  TextColumn get label => text().nullable()();
  TextColumn get selectedText => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get color => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class OutboxEntries extends Table {
  TextColumn get id => text()();
  TextColumn get providerInstanceId => text()();
  TextColumn get bookId => text()();
  TextColumn get field => text()();
  TextColumn get payload => text()(); // JSON
  TextColumn get observedRemoteRevision => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Conflicts extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get field => text()();
  TextColumn get localValue => text().nullable()(); // JSON
  TextColumn get remoteValue => text().nullable()(); // JSON
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get resolved => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
