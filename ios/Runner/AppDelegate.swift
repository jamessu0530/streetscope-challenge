import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // google_maps_flutter 在 iOS 上「必須」先初始化 API Key。
    // 改為從 Info.plist 讀取，避免硬編碼金鑰進 Git。
    let key = (Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !key.isEmpty {
      GMSServices.provideAPIKey(key)
    } else {
      assertionFailure("Missing GOOGLE_MAPS_API_KEY in Info.plist / xcconfig")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
