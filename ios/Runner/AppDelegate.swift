import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var securityEventsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let securityChannel = FlutterMethodChannel(
        name: "uchetsd/security",
        binaryMessenger: controller.binaryMessenger
      )
      securityChannel.setMethodCallHandler { call, result in
        if call.method == "setSecureScreen" {
          result(false)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      securityEventsChannel = FlutterMethodChannel(
        name: "uchetsd/security_events",
        binaryMessenger: controller.binaryMessenger
      )
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleScreenshotTaken),
        name: UIApplication.userDidTakeScreenshotNotification,
        object: nil
      )
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc private func handleScreenshotTaken() {
    securityEventsChannel?.invokeMethod(
      "screenshotTaken",
      arguments: ["timestamp": Date().timeIntervalSince1970]
    )
  }
}
