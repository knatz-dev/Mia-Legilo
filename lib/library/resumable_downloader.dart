import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

/// Progress of an in-flight download.
class DownloadProgress {
  const DownloadProgress({required this.received, this.total});

  final int received;
  final int? total;

  double? get fraction =>
      total == null || total == 0 ? null : received / total!;
}

class DownloadException implements Exception {
  // ignore: prefer_initializing_formals
  const DownloadException(String message) : message = message;

  final String message;

  @override
  String toString() => 'DownloadException: $message';
}

class DownloadCancelledException extends DownloadException {
  const DownloadCancelledException() : super('The download was cancelled.');
}

class StoragePressureException extends DownloadException {
  const StoragePressureException()
      : super('Not enough free storage to finish the download.');
}

class IntegrityException extends DownloadException {
  // ignore: use_super_parameters
  const IntegrityException(String message) : super(message);
}

/// HTTP downloader with Range-based resume, bounded size, integrity checking
/// and cancellation that keeps the partial file for a later resume.
///
/// The partial body is written to `<target>.part` with its validators in
/// `<target>.meta`. Only a fully received, size-checked (and optionally
/// SHA-256-checked) file is renamed onto [target], so the library never sees
/// a truncated EPUB.
class ResumableDownloader {
  ResumableDownloader({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 60),
                followRedirects: true,
                maxRedirects: 5,
              ),
            );

  final Dio _dio;

  static const int maxDownloadBytes = 1024 * 1024 * 1024;

  Future<File> download(
    Uri uri, {
    required File target,
    void Function(DownloadProgress progress)? onProgress,
    String? expectedSha256,
    CancelToken? cancelToken,
    Dio? dio,
  }) async {
    final ResumableDownloader impl =
        dio == null ? this : ResumableDownloader(dio: dio);
    return impl._downloadImpl(
      uri,
      target: target,
      onProgress: onProgress,
      expectedSha256: expectedSha256,
      cancelToken: cancelToken,
    );
  }

  Future<File> _downloadImpl(
    Uri uri, {
    required File target,
    void Function(DownloadProgress progress)? onProgress,
    String? expectedSha256,
    CancelToken? cancelToken,
  }) async {
    if (await target.exists()) {
      if (expectedSha256 == null) return target;
      final String actual = await _sha256Of(target);
      if (actual == expectedSha256) return target;
      await target.delete();
    }

    final File part = File('${target.path}.part');
    final File meta = File('${target.path}.meta');

    for (int attempt = 0; attempt < 2; attempt++) {
      _ResumeState state = await _ResumeState.load(part, meta);
      final Response<ResponseBody> response;
      try {
        response = await _dio.getUri<ResponseBody>(
          uri,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            validateStatus: (int? status) =>
                status != null && status >= 200 && status < 500,
            headers: <String, dynamic>{
              if (state.received > 0) 'range': 'bytes=${state.received}-',
              if (state.etag != null) 'if-range': state.etag!,
              if (state.etag == null && state.lastModified != null)
                'if-range': state.lastModified!,
              'accept': 'application/epub+zip, application/octet-stream, */*',
            },
          ),
        );
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          throw const DownloadCancelledException();
        }
        throw DownloadException('Could not reach the book source: $e');
      }

      final int status = response.statusCode ?? 0;
      if (status == 416) {
        // The partial file no longer matches the remote representation.
        await _discard(part, meta);
        continue;
      }
      if (status == 409) {
        throw const DownloadException('The book source is temporarily busy.');
      }
      if (status < 200 || status >= 300) {
        throw DownloadException('The book source returned HTTP $status.');
      }

      final bool appending = status == 206 && state.received > 0;
      if (status == 200 && state.received > 0) {
        // The server ignored Range; restart from zero.
        await _discard(part, meta);
        state = _ResumeState.empty;
      }

      final int? contentLength = _contentLength(response);
      if (contentLength != null &&
          state.received + contentLength > maxDownloadBytes) {
        throw const DownloadException('The file is larger than the 1 GB limit.');
      }

      final int? total = contentLength == null
          ? state.total
          : (appending ? state.received + contentLength : contentLength);

      await _writeResponse(
        response,
        part: part,
        meta: meta,
        append: appending,
        initialBytes: state.received,
        total: total,
        onProgress: onProgress,
      );

      final int size = await part.length();
      if (total != null && size != total) {
        // Keep the partial file: a later attempt can resume it.
        throw DownloadException(
          'The download stopped early ($size of $total bytes).',
        );
      }
      if (expectedSha256 != null) {
        final String actual = await _sha256Of(part);
        if (actual != expectedSha256) {
          await _discard(part, meta);
          throw const IntegrityException(
            'The downloaded file failed its integrity check.',
          );
        }
      }

      await _promote(part, target);
      if (await meta.exists()) await meta.delete();
      return target;
    }

    throw const DownloadException('The book source rejected the resume request.');
  }

  Future<void> _writeResponse(
    Response<ResponseBody> response, {
    required File part,
    required File meta,
    required bool append,
    required int initialBytes,
    required int? total,
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    await part.parent.create(recursive: true);
    await _writeMeta(meta, response, initialBytes, total);

    RandomAccessFile? handle;
    int received = initialBytes;
    try {
      final RandomAccessFile out =
          await part.open(mode: append ? FileMode.append : FileMode.write);
      handle = out;
      final Stream<Uint8List> stream = response.data!.stream;
      await for (final Uint8List chunk in stream) {
        received += chunk.length;
        if (received > maxDownloadBytes) {
          await out.close();
          handle = null;
          await _discard(part, meta);
          throw const DownloadException(
            'The file is larger than the 1 GB limit.',
          );
        }
        await out.writeFrom(chunk);
        onProgress?.call(DownloadProgress(received: received, total: total));
      }
      await out.flush();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw const DownloadCancelledException();
      }
      throw DownloadException('The download was interrupted: $e');
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode == 28) {
        await _discard(part, meta);
        throw const StoragePressureException();
      }
      rethrow;
    } finally {
      await handle?.close();
    }
    onProgress?.call(DownloadProgress(received: received, total: total ?? received));
  }

  Future<void> _writeMeta(
    File meta,
    Response<ResponseBody> response,
    int received,
    int? total,
  ) async {
    final Map<String, dynamic> data = <String, dynamic>{
      'received': received,
      'total': total,
      'etag': response.headers.value('etag'),
      'lastModified': response.headers.value('last-modified'),
      'url': response.requestOptions.uri.toString(),
    };
    await meta.writeAsString(jsonEncode(data), flush: true);
  }

  int? _contentLength(Response<ResponseBody> response) {
    final String? header = response.headers.value(Headers.contentLengthHeader);
    if (header == null) return null;
    return int.tryParse(header);
  }

  Future<void> _promote(File part, File target) async {
    await target.parent.create(recursive: true);
    if (await target.exists()) await target.delete();
    await part.rename(target.path);
  }

  Future<void> _discard(File part, File meta) async {
    for (final File file in <File>[part, meta]) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Best effort.
      }
    }
  }

  Future<String> _sha256Of(File file) async {
    final int length = await file.length();
    final RandomAccessFile handle = await file.open();
    try {
      final _DigestSink sink = _DigestSink();
      final ByteConversionSink input = sha256.startChunkedConversion(sink);
      const int chunkSize = 1024 * 1024;
      int remaining = length;
      while (remaining > 0) {
        final Uint8List chunk =
            await handle.read(remaining < chunkSize ? remaining : chunkSize);
        if (chunk.isEmpty) break;
        input.add(chunk);
        remaining -= chunk.length;
      }
      input.close();
      return sink.digest.toString();
    } finally {
      await handle.close();
    }
  }
}

class _ResumeState {
  const _ResumeState({
    required this.received,
    this.total,
    this.etag,
    this.lastModified,
  });

  static const _ResumeState empty = _ResumeState(received: 0);

  final int received;
  final int? total;
  final String? etag;
  final String? lastModified;

  static Future<_ResumeState> load(File part, File meta) async {
    if (!await part.exists() || !await meta.exists()) return empty;
    try {
      final Map<String, dynamic> data =
          jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      final int received = await part.length();
      if (received == 0) return empty;
      return _ResumeState(
        received: received,
        total: (data['total'] as num?)?.toInt(),
        etag: data['etag'] as String?,
        lastModified: data['lastModified'] as String?,
      );
    } catch (_) {
      return empty;
    }
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}

/// Suggests a filesystem-safe name for a downloaded book.
String suggestedDownloadName(Uri uri) {
  final String last = uri.pathSegments.isEmpty ? 'book.epub' : uri.pathSegments.last;
  final String cleaned = last.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final String name = cleaned.isEmpty ? 'book.epub' : cleaned;
  return p.extension(name).isEmpty ? '$name.epub' : name;
}
