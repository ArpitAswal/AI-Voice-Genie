import Flutter
import Photos
import UIKit

/// Native Swift handler for saving generated images to the iOS Photos library.
///
/// Uses PHPhotoLibrary with add-only authorization (PHAuthorizationStatusAuthorized
/// or limited), which corresponds to NSPhotoLibraryAddUsageDescription in Info.plist.
///
/// Channel: "com.example.voice_genie/image_save"
/// Method:  "saveImageBytes" with arguments:
///   "bytes"    → FlutterStandardTypedData (bytes) — raw image bytes
///   "fileName" → String  — included for naming context (iOS Photos ignores it)
///   "mimeType" → String  — e.g. "image/jpeg", "image/png"
///
/// Returns: Map<String, Any?>
///   "success"  → Bool
///   "error"    → String? (nil on success)
class ImageSavePlugin: NSObject, FlutterPlugin {

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.example.voice_genie/image_save",
            binaryMessenger: registrar.messenger()
        )
        let instance = ImageSavePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "saveImageBytes" else {
            result(FlutterMethodNotImplemented)
            return
        }

        guard
            let args = call.arguments as? [String: Any],
            let flutterBytes = args["bytes"] as? FlutterStandardTypedData
        else {
            result(["success": false, "error": "invalid_arguments"])
            return
        }

        let imageData = flutterBytes.data

        // Validate that the bytes can form a UIImage before attempting to save.
        guard let image = UIImage(data: imageData) else {
            result(["success": false, "error": "invalid_image_bytes"])
            return
        }

        // Request add-only authorization on iOS 14+, falling back to the older
        // Photos authorization API for earlier deployment targets.
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                self.handleAuthorizationStatus(status, image: image, result: result)
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                self.handleAuthorizationStatus(status, image: image, result: result)
            }
        }
    }

    private func handleAuthorizationStatus(
        _ status: PHAuthorizationStatus,
        image: UIImage,
        result: @escaping FlutterResult
    ) {
        switch status {
        case .authorized, .limited:
            self.saveImage(image, result: result)

        case .denied, .restricted:
            DispatchQueue.main.async {
                result(["success": false, "error": "permission_denied"])
            }

        case .notDetermined:
            DispatchQueue.main.async {
                result(["success": false, "error": "permission_not_determined"])
            }

        @unknown default:
            DispatchQueue.main.async {
                result(["success": false, "error": "permission_unknown"])
            }
        }
    }

    /// Writes a UIImage into the Photos library using a change request.
    ///
    /// PHPhotoLibrary.performChanges runs on a background queue internally,
    /// so the main thread is never blocked during the disk write.
    private func saveImage(_ image: UIImage, result: @escaping FlutterResult) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    result(["success": true, "error": nil])
                } else {
                    let reason = error?.localizedDescription ?? "unknown"
                    result(["success": false, "error": "photos_write_failed: \(reason)"])
                }
            }
        }
    }
}
