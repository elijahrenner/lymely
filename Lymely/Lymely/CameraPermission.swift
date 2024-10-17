import AVFoundation
import Combine

/// A class that manages camera permission for the app.
/// It provides a way to check and request camera access.
class CameraPermission: ObservableObject {
    /// A published property that indicates whether camera permission is granted.
    /// This property will update its observers when its value changes.
    @Published var isCameraPermissionGranted: Bool = false

    /// Requests camera permission from the user.
    /// This function checks the current authorization status and acts accordingly:
    /// - If the status is not determined, it requests access from the user.
    /// - If the status is already authorized, it sets the permission to granted.
    /// - For any other status (denied or restricted), it sets the permission to not granted.
    /// The function updates the `isCameraPermissionGranted` property on the main thread.
    func getCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            await AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isCameraPermissionGranted = granted
                }
            }
        } else if status == .authorized {
            DispatchQueue.main.async {
                self.isCameraPermissionGranted = true
            }
        } else {
            DispatchQueue.main.async {
                self.isCameraPermissionGranted = false
            }
        }
    }
}
