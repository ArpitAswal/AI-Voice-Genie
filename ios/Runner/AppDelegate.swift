import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Register the native image-save MethodChannel.
    // This lets Dart call Photos framework to save generated images.
    ImageSavePlugin.register(with: self.registrar(forPlugin: "ImageSavePlugin")!)
    self.window?.makeSecure()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}


extension UIWindow {
  func makeSecure() {
    let field = UITextField()
    field.isSecureTextEntry = true
    self.addSubview(field)
    field.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
    field.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
    self.layer.superlayer?.addSublayer(field.layer)
    field.layer.sublayers?.last?.addSublayer(self.layer)
  }
}
