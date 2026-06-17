import CoreGraphics
import Foundation

/// Thin wrapper over the private DisplayServices framework used to read and
/// set display brightness. These symbols are not public API but are stable and
/// widely used; failures are tolerated silently (best effort per display).
enum BrightnessControl {
    private typealias GetFunc = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFunc = @convention(c) (UInt32, Float) -> Int32

    nonisolated(unsafe) private static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_NOW
    )

    private static let getFn: GetFunc? = handle
        .flatMap { dlsym($0, "DisplayServicesGetBrightness") }
        .map { unsafeBitCast($0, to: GetFunc.self) }

    private static let setFn: SetFunc? = handle
        .flatMap { dlsym($0, "DisplayServicesSetBrightness") }
        .map { unsafeBitCast($0, to: SetFunc.self) }

    static func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return []
        }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else {
            return []
        }

        return ids
    }

    /// Snapshot of every display's current brightness, for later restore.
    static func snapshot() -> [CGDirectDisplayID: Float] {
        guard let getFn else { return [:] }

        var result: [CGDirectDisplayID: Float] = [:]
        for id in activeDisplays() {
            var value: Float = 0
            if getFn(id, &value) == 0 {
                result[id] = value
            }
        }
        return result
    }

    static func setBrightness(_ value: Float) {
        guard let setFn else { return }
        for id in activeDisplays() {
            _ = setFn(id, value)
        }
    }

    static func restore(_ snapshot: [CGDirectDisplayID: Float]) {
        guard let setFn else { return }
        for (id, value) in snapshot {
            _ = setFn(id, value)
        }
    }
}
