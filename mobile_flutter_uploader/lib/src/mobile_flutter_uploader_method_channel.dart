import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mobile_flutter_uploader_platform_interface.dart';

/// An implementation of [MobileFlutterUploaderPlatform] that uses method channels.
class MethodChannelMobileFlutterUploader extends MobileFlutterUploaderPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('mobile_flutter_uploader');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<String> uploadFile({
    required Uri uri,
    required String filePath,
  }) async {
    final task = await methodChannel.invokeMethod<String>(
      'uploadFile',
      {
        'url': uri.toString(),
        'file_path': filePath,
      },
    );
    return task!;
  }
}
