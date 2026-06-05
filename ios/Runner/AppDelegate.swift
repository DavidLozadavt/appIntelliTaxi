import Flutter
import UIKit
import FirebaseCore // 1. Importa el núcleo de Firebase

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appChannelName = "com.virtualt.intellitaxi/app"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 2. Inicializa Firebase a nivel nativo para iOS
    FirebaseApp.configure() 
    
    // 3. Registra tu app para recibir notificaciones push remotas
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()

    if let controller = window?.rootViewController as? FlutterViewController {
      registerAppChannel(controller: controller)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func registerAppChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: appChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "checkFreshInstall":
        result([
          "firstInstallMs": self.readInstallEpochMs(),
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Aproximación al epoch de instalación (cambia al reinstalar la app).
  private func readInstallEpochMs() -> Int64 {
    let path = Bundle.main.bundlePath
    if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
       let created = attrs[.creationDate] as? Date {
      return Int64(created.timeIntervalSince1970 * 1000)
    }
    return Int64(Date().timeIntervalSince1970 * 1000)
  }
}