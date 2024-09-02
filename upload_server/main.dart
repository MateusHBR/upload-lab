import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'constants.dart';

Future<HttpServer> run(Handler handler, InternetAddress ip, int port) async {
  if (!Directory(uploadDirectory).existsSync()) {
    await Directory(uploadDirectory).create();
  }

  return serve(
    handler,
    ip,
    port,
    poweredByHeader: 'Dart',
  );
}
