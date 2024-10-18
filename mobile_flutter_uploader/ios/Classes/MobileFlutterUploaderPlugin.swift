import Flutter
import UIKit

public class MobileFlutterUploaderPlugin: NSObject, FlutterPlugin {
    static let stepUpdate = 0

    public static var registerPlugins: FlutterPluginRegistrantCallback?
    private var headlessRunner: FlutterEngine?
    var registeredPlugins: Bool = false
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "mobile_flutter_uploader", binaryMessenger: registrar.messenger())
        
        let instance = MobileFlutterUploaderPlugin()
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("Trigger method: \(call.method)")
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "uploadFile":
            guard let args = (call.arguments as? [String: Any]) else {
                result(FlutterError(code: "-1", message: "invalid arguments", details: call.arguments))
                return
            }
            uploadFile(args, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func uploadFile(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let filePath = args["file_path"] as? String else {
            result(FlutterError(code: "-1", message: "invalid arguments", details: args))
            return
        }
        guard let urlString = args["url"] as? String, let url = URL(string: urlString) else {
            let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "invalid url"])
            result(FlutterError(code: "-1", message: "invalid arguments", details: error))
            return
        }
        
        print("RECEIVED ARGS: \(args)")
        let session = UploaderService.shared.createUploadTask(uploadURL: url, filePath: filePath)
        result(session.id)
    }
}

// MARK: - UIApplicationDelegate
extension MobileFlutterUploaderPlugin {
    public func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) -> Bool {
        print("ApplicationHandleEventsForBackgroundURLSession: \(identifier)")
        if identifier == URLSessionUploader.Keys.backgroundSessionIdentifier {
            URLSessionUploader.shared.backgroundTransferCompletionHander = completionHandler
        }

        return true
    }

    public func applicationWillTerminate(_ application: UIApplication) {
    }
}
