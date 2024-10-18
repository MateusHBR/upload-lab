import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import '../../../constants.dart';

Future<Response> onRequest(
  RequestContext context,
  String id,
) async {
  final request = context.request;
  await Future.delayed(Duration(seconds: 10));

  final contentRangeFromHeader = request.headers['content-range'];
  final contentLength = int.tryParse(request.headers['content-length'] ?? '');
  final contentType = request.headers['content-type'];
  if (contentRangeFromHeader == null ||
      contentLength == null ||
      contentType == null) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {
        'data': 'Missing Content-Range, Content-Length or Content-Type header.',
      },
    );
  }

  final ({int start, int end, int total}) contentRange;
  try {
    contentRange = _getContentRange(contentRangeFromHeader);
  } on Exception {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'data': 'Invalid Content-Range format.'},
    );
  }

  final expectedChunkSize = contentRange.end - contentRange.start + 1;
  if (contentLength != expectedChunkSize) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'data': 'Chunk size does not match Content-Range.'},
    );
  }

  final filePath = '$uploadDirectory/$id.part';
  final file = File(filePath);
  if (!file.existsSync()) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'data': 'Upload session does not exists for specified file.'},
    );
  }

  final raf = await file.open(mode: FileMode.writeOnlyAppend);
  await raf.setPosition(contentRange.start);
  await for (final chunk in request.bytes()) {
    raf.writeFromSync(chunk);
  }
  await raf.close();

  if (await file.length() == contentRange.total) {
    final finalFile = File('$uploadDirectory/$id.$contentType');
    await file.rename(finalFile.path);
    return Response.json(body: {'data': 'Upload completed!'});
  }

  return Response.json(
    statusCode: HttpStatus.permanentRedirect,
    body: {'data': 'Chunk uploaded!'},
  );
}

({int start, int end, int total}) _getContentRange(String contentRange) {
  final contentRangePattern = RegExp(r'bytes (\d+)-(\d+)/(\d+)');
  final match = contentRangePattern.firstMatch(contentRange);
  if (match == null) {
    throw Exception('Failed to get content rage');
  }

  final start = int.parse(match.group(1)!);
  final end = int.parse(match.group(2)!);
  final total = int.parse(match.group(3)!);

  return (
    start: start,
    end: end,
    total: total,
  );
}
