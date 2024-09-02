import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import '../constants.dart';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  final formData = await request.formData();
  final file = formData.files['file'];
  if (file == null) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'data': 'Expected "file", found nothing'},
    );
  }

  if (!Directory(uploadDirectory).existsSync()) {
    await Directory(uploadDirectory).create();
  }

  final fileExtension = file.name.split('.').last;
  final bytes = await file.readAsBytes();
  await File(
    '$uploadDirectory/${uuid.v4()}.$fileExtension',
  ).writeAsBytes(bytes);
  return Response.json(
    body: {
      'data': 'Successfully uploaded!',
    },
  );
}
