import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var storageChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    storageChannel = FlutterMethodChannel(
      name: "expense_tracker/private_storage",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    storageChannel?.setMethodCallHandler { call, result in
      guard call.method == "prepareLedgerDirectory" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        let files = FileManager.default
        let support = try files.url(
          for: .applicationSupportDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: true
        )
        var ledger = support.appendingPathComponent("ledger", isDirectory: true)
        try files.createDirectory(
          at: ledger,
          withIntermediateDirectories: true,
          attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        try files.setAttributes(
          [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
          ofItemAtPath: ledger.path
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try ledger.setResourceValues(values)
        // Also protect previously existing SQLite/journal/WAL files.
        for file in try files.contentsOfDirectory(at: ledger, includingPropertiesForKeys: nil) {
          try files.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: file.path
          )
        }
        result(ledger.path)
      } catch {
        result(FlutterError(
          code: "storage_unavailable",
          message: "Cannot prepare ledger storage",
          details: nil
        ))
      }
    }
  }
}
