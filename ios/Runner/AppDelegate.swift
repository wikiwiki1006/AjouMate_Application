import Flutter
import UIKit
import NMapsMap

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 네이버 지도 SDK 직접 초기화 (NCP 새로운 Maps 상품 방식)
    NMFAuthManager.shared().ncpKeyId = "fgdysmkced"
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
