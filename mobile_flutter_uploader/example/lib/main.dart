import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:mobile_flutter_uploader/mobile_flutter_uploader.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _mobileFlutterUploaderPlugin = MobileFlutterUploader();

  @override
  void initState() {
    super.initState();
    initPlatformState();
    final documentsDirectory = getApplicationDocumentsDirectory();
    documentsDirectory.then((value) async {
      print(value.path);
      final firstChunk = value.listSync().firstWhere(
            (el) => el.path.contains('chunk_0'),
          );

      final taskId = await _mobileFlutterUploaderPlugin.uploadFile(
        uri: Uri(
          scheme: 'http',
          host: 'localhost',
          port: 8080,
          path: 'resumable/upload/1728602810546',
        ),
        filePath: firstChunk.path,
      );
      print('taskId: $taskId');

      // final secondChunk = value.listSync().firstWhere(
      //       (el) => el.path.contains('chunk_1'),
      //     );
      // await _mobileFlutterUploaderPlugin.uploadFile(
      //   uri: Uri(
      //     scheme: 'http',
      //     host: 'localhost',
      //     port: 8080,
      //     path: 'resumable/upload/1728519623787',
      //   ),
      //   filePath: secondChunk.path,
      // );
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _mobileFlutterUploaderPlugin.getPlatformVersion() ??
              'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text('Running on: $_platformVersion\n'),
        ),
      ),
    );
  }
}
