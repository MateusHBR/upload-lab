import UIKit
import Flutter
import mobile_flutter_uploader

func registerPlugins(registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      GeneratedPluginRegistrant.register(with: self)
      
      MobileFlutterUploaderPlugin.registerPlugins = registerPlugins
      
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
