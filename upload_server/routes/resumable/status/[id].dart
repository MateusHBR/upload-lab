import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import '../../../constants.dart';

Future<Response> onRequest(
  RequestContext context,
  String id,
) async {
  final filePath = '$uploadDirectory/$id.part';
  final file = File(filePath);

  if (!file.existsSync()) {
    return Response.json(
      statusCode: HttpStatus.notFound,
      body: {'data': 'Upload ID not found.'},
    );
  }

  final uploadedBytes = await file.length();
  final response = {'uploadedBytes': uploadedBytes};
  return Response.json(
    body: response,
  );
}
