import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter_uploader/mobile_flutter_uploader.dart';
import 'package:mobile_flutter_uploader/src/mobile_flutter_uploader_method_channel.dart';
import 'package:mobile_flutter_uploader/src/mobile_flutter_uploader_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMobileFlutterUploaderPlatform
    with MockPlatformInterfaceMixin
    implements MobileFlutterUploaderPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<String> uploadFile({required Uri uri, required String filePath}) =>
      Future.value('1');
}

void main() {
  final MobileFlutterUploaderPlatform initialPlatform =
      MobileFlutterUploaderPlatform.instance;

  test('$MethodChannelMobileFlutterUploader is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMobileFlutterUploader>());
  });

  test('getPlatformVersion', () async {
    MobileFlutterUploader mobileFlutterUploaderPlugin = MobileFlutterUploader();
    MockMobileFlutterUploaderPlatform fakePlatform =
        MockMobileFlutterUploaderPlatform();
    MobileFlutterUploaderPlatform.instance = fakePlatform;

    expect(await mobileFlutterUploaderPlugin.getPlatformVersion(), '42');
  });
}
