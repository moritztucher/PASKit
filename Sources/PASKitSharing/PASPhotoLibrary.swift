//
//  PASPhotoLibrary.swift
//  PASKitSharing
//
//  Save-to-Photos with the add-only permission flow. The consuming app
//  must declare `NSPhotoLibraryAddUsageDescription` in its Info.plist.
//

#if canImport(UIKit)
import Photos
import UIKit

public enum PASPhotoLibraryError: Error, LocalizedError {
    case accessDenied
    case saveFailed(underlying: any Error)

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photos access was denied. Allow adding to Photos in Settings."
        case .saveFailed(let underlying):
            return "Saving to Photos failed: \(underlying.localizedDescription)"
        }
    }
}

/// Saves rendered images to the user's photo library.
///
/// ```swift
/// try await PASPhotoLibrary.save(storyImage)
/// Haptics.play(.success, isEnabled: settings.hapticsEnabled)
/// ```
public enum PASPhotoLibrary {
    /// Requests add-only authorization if needed, then saves the image.
    /// `.limited` access is sufficient — adding is always allowed there.
    public static func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PASPhotoLibraryError.accessDenied
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        } catch {
            throw PASPhotoLibraryError.saveFailed(underlying: error)
        }
    }
}
#endif
