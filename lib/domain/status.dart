/// Reading status model (independent of progress and download state).
enum ReadingStatus {
  unread,
  wantToRead,
  reading,
  completed,
  onHold,
  abandoned,
}

extension ReadingStatusX on ReadingStatus {
  String get label => switch (this) {
        ReadingStatus.unread => 'Unread',
        ReadingStatus.wantToRead => 'Want to Read',
        ReadingStatus.reading => 'Reading',
        ReadingStatus.completed => 'Completed',
        ReadingStatus.onHold => 'On Hold',
        ReadingStatus.abandoned => 'Abandoned',
      };
}
