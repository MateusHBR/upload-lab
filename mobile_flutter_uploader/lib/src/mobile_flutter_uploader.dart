import 'mobile_flutter_uploader_platform_interface.dart';

class MobileFlutterUploader {
  Future<String?> getPlatformVersion() {
    return MobileFlutterUploaderPlatform.instance.getPlatformVersion();
  }

  Future<String> uploadFile({
    required Uri uri,
    required String filePath,
  }) {
    return MobileFlutterUploaderPlatform.instance.uploadFile(
      uri: uri,
      filePath: filePath,
    );
  }
}
