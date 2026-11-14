import 'ids.dart';
import 'status.dart';
import 'locator.dart';
import 'provenance.dart';

/// Download availability state (independent of reading status).
enum DownloadState { notDownloaded, downloading, downloaded, failed, removed }

/// A book in the local library. Identity is [BookId], never title/author similarity.
class Book {
  const Book({
    required this.id,
    required this.title,
    this.authors = const <String>[],
    this.series,
    this.seriesIndex,
    this.description,
    this.coverPath,
    this.readingStatus = ReadingStatus.unread,
    this.locator,
    this.remoteIdentity,
    this.downloadState = DownloadState.notDownloaded,
    this.localAssetId,
    this.shelfIds = const <ShelfId>[],
    this.addedAt,
    this.lastReadAt,
    this.progressPercentage,
    this.metadataProvenance = MetadataProvenance.standard,
  });

  final BookId id;
  final String title;
  final List<String> authors;
  final String? series;
  final double? seriesIndex;
  final String? description;
  final String? coverPath;
  final ReadingStatus readingStatus;
  final ReadingLocator? locator;
  final RemoteIdentity? remoteIdentity;
  final DownloadState downloadState;
  final BookId? localAssetId;
  final List<ShelfId> shelfIds;
  final DateTime? addedAt;
  final DateTime? lastReadAt;
  final double? progressPercentage;
  final MetadataProvenance metadataProvenance;

  Book copyWith({
    String? title,
    List<String>? authors,
    String? series,
    double? seriesIndex,
    String? description,
    String? coverPath,
    ReadingStatus? readingStatus,
    ReadingLocator? locator,
    RemoteIdentity? remoteIdentity,
    DownloadState? downloadState,
    BookId? localAssetId,
    List<ShelfId>? shelfIds,
    DateTime? addedAt,
    DateTime? lastReadAt,
    double? progressPercentage,
    MetadataProvenance? metadataProvenance,
  }) =>
      Book(
        id: id,
        title: title ?? this.title,
        authors: authors ?? this.authors,
        series: series ?? this.series,
        seriesIndex: seriesIndex ?? this.seriesIndex,
        description: description ?? this.description,
        coverPath: coverPath ?? this.coverPath,
        readingStatus: readingStatus ?? this.readingStatus,
        locator: locator ?? this.locator,
        remoteIdentity: remoteIdentity ?? this.remoteIdentity,
        downloadState: downloadState ?? this.downloadState,
        localAssetId: localAssetId ?? this.localAssetId,
        shelfIds: shelfIds ?? this.shelfIds,
        addedAt: addedAt ?? this.addedAt,
        lastReadAt: lastReadAt ?? this.lastReadAt,
        progressPercentage: progressPercentage ?? this.progressPercentage,
        metadataProvenance: metadataProvenance ?? this.metadataProvenance,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id.toJson(),
        'title': title,
        'authors': authors,
        'series': series,
        'seriesIndex': seriesIndex,
        'description': description,
        'coverPath': coverPath,
        'readingStatus': readingStatus.name,
        'locator': locator?.toJson(),
        'remoteIdentity': remoteIdentity?.toJson(),
        'downloadState': downloadState.name,
        'localAssetId': localAssetId?.toJson(),
        'shelfIds': shelfIds.map((s) => s.toJson()).toList(),
        'addedAt': addedAt?.toIso8601String(),
        'lastReadAt': lastReadAt?.toIso8601String(),
        'progressPercentage': progressPercentage,
        'metadataProvenance': metadataProvenance.name,
      };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: BookId.fromJson(json['id'] as Map<String, dynamic>),
        title: json['title'] as String,
        authors: (json['authors'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => e as String)
            .toList(),
        series: json['series'] as String?,
        seriesIndex: (json['seriesIndex'] as num?)?.toDouble(),
        description: json['description'] as String?,
        coverPath: json['coverPath'] as String?,
        readingStatus: ReadingStatus.values.firstWhere(
          (s) => s.name == json['readingStatus'],
          orElse: () => ReadingStatus.unread,
        ),
        locator: json['locator'] == null
            ? null
            : ReadingLocator.fromJson(json['locator'] as Map<String, dynamic>),
        remoteIdentity: json['remoteIdentity'] == null
            ? null
            : RemoteIdentity.fromJson(
                json['remoteIdentity'] as Map<String, dynamic>),
        downloadState: DownloadState.values.firstWhere(
          (s) => s.name == json['downloadState'],
          orElse: () => DownloadState.notDownloaded,
        ),
        localAssetId: json['localAssetId'] == null
            ? null
            : BookId.fromJson(json['localAssetId'] as Map<String, dynamic>),
        shelfIds: (json['shelfIds'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => ShelfId.fromJson(e as Map<String, dynamic>))
            .toList(),
        addedAt: json['addedAt'] == null
            ? null
            : DateTime.parse(json['addedAt'] as String),
        lastReadAt: json['lastReadAt'] == null
            ? null
            : DateTime.parse(json['lastReadAt'] as String),
        progressPercentage: (json['progressPercentage'] as num?)?.toDouble(),
        metadataProvenance: MetadataProvenance.values.firstWhere(
          (p) => p.name == json['metadataProvenance'],
          orElse: () => MetadataProvenance.standard,
        ),
      );

  @override
  bool operator ==(Object other) => other is Book && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
