import Cocoa
import FlutterMacOS

/// SlaxxFM main window (copied over the generated file by
/// tool/patch_platforms.dart).
///
/// Channel "slaxxfm/locks":
///  - acquire: while a station plays, keep the app out of App Nap and
///    stop the Mac from going to idle sleep (the display may still sleep).
///  - release: allow both again.
///  - "wake" is sent to Dart when the Mac wakes up, so the stream is
///    reconnected immediately.
class MainFlutterWindow: NSWindow {
  private var channel: FlutterMethodChannel?
  private var activity: NSObjectProtocol?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let ch = FlutterMethodChannel(
      name: "slaxxfm/locks",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    ch.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "acquire":
        self?.acquire()
        result(true)
      case "release":
        self?.releaseActivity()
        result(true)
      case "batteryOptimized":
        result(false)
      case "requestBatteryExemption":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    channel = ch

    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.channel?.invokeMethod("wake", arguments: nil)
    }

    super.awakeFromNib()
  }

  private func acquire() {
    if activity != nil { return }
    activity = ProcessInfo.processInfo.beginActivity(
      options: [.userInitiated, .idleSystemSleepDisabled],
      reason: "SlaxxFM spielt Radio")
  }

  private func releaseActivity() {
    if let a = activity {
      ProcessInfo.processInfo.endActivity(a)
      activity = nil
    }
  }
}
