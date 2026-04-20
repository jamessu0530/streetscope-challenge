import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // google_maps_flutter 在 iOS 上「必須」在建立任何 GoogleMap 之前初始化 API Key，
    // 否則會在 GMSServices.checkServicePreconditions 直接 crash。
    // TODO: 改成與 lib/main.dart 裡 kGoogleApiKey 相同的金鑰（Maps SDK for iOS 用）。
    GMSServices.provideAPIKey("AIzaSyBTpFnJouBuKVdmv4y9QNeZIk1pzcuYK1k")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
