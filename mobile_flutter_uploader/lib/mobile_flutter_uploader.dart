
import 'mobile_flutter_uploader_platform_interface.dart';

class MobileFlutterUploader {
  Future<String?> getPlatformVersion() {
    return MobileFlutterUploaderPlatform.instance.getPlatformVersion();
  }
}
