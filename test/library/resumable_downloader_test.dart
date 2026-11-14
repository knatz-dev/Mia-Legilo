import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/library/resumable_downloader.dart';

void main() {
  late HttpServer server;
  late Directory temp;
  late List<int> payload;
  late String etag;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mia_download_test_');
    payload = List<int>.generate(200 * 1024, (int i) => i % 251);
    etag = '"v1"';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(_serve(server, payload, etag));
  });

  tearDown(() async {
    await server.close(force: true);
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('downloads a complete file and promotes it atomically', () async {
    final File target = File('${temp.path}/book.epub');
    final ResumableDownloader downloader = ResumableDownloader();
    final List<DownloadProgress> progress = <DownloadProgress>[];

    final File result = await downloader.download(
      Uri.parse('http://${server.address.host}:${server.port}/book.epub'),
      target: target,
      onProgress: progress.add,
    );

    expect(await result.readAsBytes(), payload);
    expect(await File('${target.path}.part').exists(), isFalse);
    expect(progress, isNotEmpty);
    expect(progress.last.received, payload.length);
  });

  test('resumes a partial download with a Range request', () async {
    final File target = File('${temp.path}/book.epub');
    final int offset = 80 * 1024;
    final File part = File('${target.path}.part');
    await part.writeAsBytes(payload.sublist(0, offset), flush: true);
    await File('${target.path}.meta').writeAsString(
      jsonEncode(<String, dynamic>{
        'received': offset,
        'total': payload.length,
        'etag': etag,
        'lastModified': null,
        'url': 'http://${server.address.host}:${server.port}/book.epub',
      }),
      flush: true,
    );

    final File result = await ResumableDownloader().download(
      Uri.parse('http://${server.address.host}:${server.port}/book.epub'),
      target: target,
    );

    expect(await result.readAsBytes(), payload);
  });

  test('restarts when the server ignores Range', () async {
    final File target = File('${temp.path}/book.epub');
    final File part = File('${target.path}.part');
    await part.writeAsBytes(payload.sublist(0, 1024), flush: true);
    await File('${target.path}.meta').writeAsString(
      jsonEncode(<String, dynamic>{'received': 1024, 'total': payload.length}),
      flush: true,
    );

    final File result = await ResumableDownloader().download(
      Uri.parse('http://${server.address.host}:${server.port}/no-range'),
      target: target,
    );

    expect(await result.readAsBytes(), payload);
  });

  test('fails integrity checks without promoting the file', () async {
    final File target = File('${temp.path}/book.epub');

    await expectLater(
      ResumableDownloader().download(
        Uri.parse('http://${server.address.host}:${server.port}/book.epub'),
        target: target,
        expectedSha256: '0' * 64,
      ),
      throwsA(isA<IntegrityException>()),
    );

    expect(await target.exists(), isFalse);
    expect(await File('${target.path}.part').exists(), isFalse);
  });

  test('accepts a matching expected hash', () async {
    final File target = File('${temp.path}/book.epub');
    final String expected = sha256.convert(payload).toString();

    final File result = await ResumableDownloader().download(
      Uri.parse('http://${server.address.host}:${server.port}/book.epub'),
      target: target,
      expectedSha256: expected,
    );

    expect(await result.readAsBytes(), payload);
  });

  test('reports HTTP errors', () async {
    await expectLater(
      ResumableDownloader().download(
        Uri.parse('http://${server.address.host}:${server.port}/missing'),
        target: File('${temp.path}/missing.epub'),
      ),
      throwsA(isA<DownloadException>()),
    );
  });
}

Future<void> _serve(
  HttpServer server,
  List<int> payload,
  String etag,
) async {
  await for (final HttpRequest request in server) {
    final HttpResponse response = request.response;
    if (request.uri.path == '/missing') {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      continue;
    }
    if (request.uri.path == '/no-range') {
      response.headers.contentType = ContentType.binary;
      response.contentLength = payload.length;
      response.add(payload);
      await response.close();
      continue;
    }

    response.headers.set('etag', etag);
    response.headers.contentType = ContentType.binary;
    final String? range = request.headers.value('range');
    final String? ifRange = request.headers.value('if-range');
    if (range != null && (ifRange == null || ifRange == etag)) {
      final int start = int.parse(
        RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!,
      );
      final List<int> slice = payload.sublist(start);
      response.statusCode = HttpStatus.partialContent;
      response.headers.set(
        'content-range',
        'bytes $start-${payload.length - 1}/${payload.length}',
      );
      response.contentLength = slice.length;
      response.add(slice);
    } else {
      response.contentLength = payload.length;
      response.add(payload);
    }
    await response.close();
  }
}
