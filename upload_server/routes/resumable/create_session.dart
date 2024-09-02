import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import '../../constants.dart';

Future<Response> onRequest(RequestContext context) async {
  final uploadId = DateTime.now().millisecondsSinceEpoch.toString();
  final filePath = '$uploadDirectory/$uploadId.part';
  final file = File(filePath);
  await file.create();

  final response = {
    'uploadId': uploadId,
    'filePath': filePath,
  };

  return Response.json(
    body: {
      'data': response,
    },
  );
}
