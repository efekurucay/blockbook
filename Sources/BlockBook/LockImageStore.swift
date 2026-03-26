import AppKit
import Foundation

enum LockImageStoreError: LocalizedError {
    case applicationSupportUnavailable
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            "Application Support klasoru bulunamadi."
        case .invalidImage:
            "Secilen dosya gecerli bir gorsel degil."
        }
    }
}

struct LockImageStore {
    private let fileManager: FileManager
    private let baseURL: URL

    init(fileManager: FileManager = .default, baseURL: URL? = nil) throws {
        self.fileManager = fileManager
        self.baseURL = try baseURL ?? Self.defaultBaseURL(fileManager: fileManager)
    }

    func loadImage() -> NSImage? {
        guard let url = storedImageURL() else { return nil }
        return NSImage(contentsOf: url)
    }

    @discardableResult
    func storeImage(from sourceURL: URL) throws -> URL {
        guard let image = NSImage(contentsOf: sourceURL), image.isValid else {
            throw LockImageStoreError.invalidImage
        }

        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try removeStoredImages()

        let destinationURL = destinationURL(for: sourceURL)

        guard let data = try? Data(contentsOf: sourceURL) else {
            throw LockImageStoreError.invalidImage
        }

        try data.write(to: destinationURL, options: .atomic)
        _ = image
        return destinationURL
    }

    func storedImageURL() -> URL? {
        let directoryContents = (try? fileManager.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return directoryContents
            .filter { $0.lastPathComponent.hasPrefix("lock-image.") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .first
    }

    private func destinationURL(for sourceURL: URL) -> URL {
        let fileExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension.lowercased()
        return baseURL
            .appendingPathComponent("lock-image", conformingTo: .data)
            .appendingPathExtension(fileExtension)
    }

    private func removeStoredImages() throws {
        guard fileManager.fileExists(atPath: baseURL.path) else { return }

        for url in (try? fileManager.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? [] where url.lastPathComponent.hasPrefix("lock-image.") {
            try fileManager.removeItem(at: url)
        }
    }

    private static func defaultBaseURL(fileManager: FileManager) throws -> URL {
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw LockImageStoreError.applicationSupportUnavailable
        }

        return applicationSupportURL.appendingPathComponent("BlockBook", isDirectory: true)
    }
}
