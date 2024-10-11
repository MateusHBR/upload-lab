import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'mobile_flutter_uploader_method_channel.dart';

abstract class MobileFlutterUploaderPlatform extends PlatformInterface {
  /// Constructs a MobileFlutterUploaderPlatform.
  MobileFlutterUploaderPlatform() : super(token: _token);

  static final Object _token = Object();

  static MobileFlutterUploaderPlatform _instance =
      MethodChannelMobileFlutterUploader();

  /// The default instance of [MobileFlutterUploaderPlatform] to use.
  ///
  /// Defaults to [MethodChannelMobileFlutterUploader].
  static MobileFlutterUploaderPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MobileFlutterUploaderPlatform] when
  /// they register themselves.
  static set instance(MobileFlutterUploaderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String> uploadFile({
    required Uri uri,
    required String filePath,
  }) {
    throw UnimplementedError('uploadFile() has not been implemented.');
  }
}
