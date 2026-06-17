import AppKit
@preconcurrency import ApplicationServices
import LocalAuthentication
import UniformTypeIdentifiers

enum LockControllerError: LocalizedError {
    case eventTapUnavailable

    var errorDescription: String? {
        switch self {
        case .eventTapUnavailable:
            "CGEvent tap olusturulamadi. Accessibility izni verildigini dogrulayin."
        }
    }
}

@MainActor
final class LockController {
    private enum ModalState {
        case none
        case unlockPrompt
        case imagePicker
    }

    private enum PromptResult {
        case submitted(String)
        case cancelled
    }

    private let configuration: LockConfiguration
    private let imageStore: LockImageStore?
    private var overlayWindows: [LockWindow] = []
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var previewRevealTimer: Timer?
    private var previewImageAvailable = false
    private var previewVisible = false
    private var modalState: ModalState = .none
    private var cursorHidden = false

    init(configuration: LockConfiguration) {
        self.configuration = configuration
        self.imageStore = try? LockImageStore()
    }

    func activate() throws {
        guard overlayWindows.isEmpty, eventTap == nil else { return }

        createOverlayWindows()
        try installEventTap()
        hideCursorIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
    }

    func deactivate() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        eventTap = nil
        eventTapSource = nil
        previewImageAvailable = false
        modalState = .none
        previewVisible = false
        previewRevealTimer?.invalidate()
        previewRevealTimer = nil

        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()

        unhideCursorIfNeeded()
    }

    private func createOverlayWindows() {
        overlayWindows = NSScreen.screens.map { screen in
            let window = LockWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )

            window.level = .screenSaver
            window.backgroundColor = NSColor.clear
            window.isOpaque = false
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = false
            window.isMovable = false
            window.tabbingMode = .disallowed
            window.contentView = LockOverlayView(frame: screen.frame, configuration: configuration)
            window.orderFrontRegardless()

            return window
        }
    }

    private func installEventTap() throws {
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passRetained(event)
            }

            let controller = Unmanaged<LockController>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            return controller.handleEvent(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw LockControllerError.eventTapUnavailable
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        eventTapSource = source
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        default:
            break
        }

        if modalState != .none {
            return Unmanaged.passRetained(event)
        }

        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))

            if configuration.unlockShortcut.matches(keyCode: keyCode, modifierFlags: flags) {
                modalState = .unlockPrompt
                DispatchQueue.main.async { [weak self] in
                    self?.attemptBiometricUnlock()
                }
                return nil
            }

        }

        return nil
    }

    private func attemptBiometricUnlock() {
        guard modalState == .unlockPrompt else { return }

        let context = LAContext()
        context.localizedFallbackTitle = ""
        var authError: NSError?

        // No Touch ID / device-owner auth available -> straight to password prompt.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            showUnlockPrompt()
            return
        }

        // The overlay windows sit at .screenSaver level and would hide the
        // system Touch ID dialog. Drop them while authenticating; input stays
        // blocked by the event tap regardless of window level.
        setOverlayWindowsLevel(.normal)
        NSApp.activate(ignoringOtherApps: true)

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: configuration.biometricReason
        ) { [weak self] success, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.setOverlayWindowsLevel(.screenSaver)
                guard self.modalState == .unlockPrompt else { return }

                if success {
                    self.unlockAndTerminate()
                } else {
                    // User cancelled or biometry failed -> fall back to password.
                    self.showUnlockPrompt()
                }
            }
        }
    }

    private func showUnlockPrompt() {
        guard modalState == .unlockPrompt else { return }
        defer {
            if modalState == .unlockPrompt {
                modalState = .none
            }
        }

        var message = configuration.unlockMessage

        while true {
            switch runPrompt(message: message) {
            case .cancelled:
                return
            case .submitted(let password):
                guard password == configuration.unlockPassword else {
                    NSSound.beep()
                    message = configuration.invalidPasswordMessage
                    continue
                }

                unlockAndTerminate()
                return
            }
        }
    }

    private func showImagePicker() {
        guard modalState == .imagePicker else { return }
        defer { modalState = .none }

        let openPanel = NSOpenPanel()
        openPanel.title = configuration.imagePickerTitle
        openPanel.message = configuration.imagePickerMessage
        openPanel.allowedContentTypes = [.image]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)

        NSApp.activate(ignoringOtherApps: true)

        guard openPanel.runModal() == .OK, let selectedURL = openPanel.url else {
            return
        }

        do {
            guard let imageStore else {
                throw LockImageStoreError.applicationSupportUnavailable
            }

            try imageStore.storeImage(from: selectedURL)
            refreshStoredPreviewImage()
            revealPreviewIfNeeded()
        } catch {
            presentInformationalAlert(
                title: "Gorsel kaydedilemedi",
                message: error.localizedDescription
            )
        }
    }

    private func runPrompt(message: String) -> PromptResult {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = configuration.unlockTitle
        alert.informativeText = message

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "Parola"
        alert.accessoryView = field

        alert.addButton(withTitle: "Kilidi Ac")
        alert.addButton(withTitle: "Vazgec")

        let alertWindow = alert.window
        alertWindow.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        alertWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        alertWindow.tabbingMode = .disallowed
        alertWindow.center()

        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            alertWindow.makeFirstResponder(field)
        }

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            return .submitted(field.stringValue)
        }

        return .cancelled
    }

    private func presentInformationalAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Tamam")

        let alertWindow = alert.window
        alertWindow.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        alertWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        alertWindow.tabbingMode = .disallowed

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func unlockAndTerminate() {
        deactivate()
        NSApp.terminate(nil)
    }

    private func revealPreviewIfNeeded() {
        guard previewImageAvailable else { return }
        guard !previewVisible else { return }

        previewVisible = true
        previewRevealTimer?.invalidate()
        previewRevealTimer = nil

        overlayViews.forEach { $0.revealPreview() }
    }

    private func refreshStoredPreviewImage() {
        previewImageAvailable = false
        overlayViews.forEach { $0.setPreviewImage(nil) }
    }

    private func schedulePreviewRevealTimer() {
        previewRevealTimer?.invalidate()

        guard configuration.previewRevealDelay > 0 else { return }

        let timer = Timer(timeInterval: configuration.previewRevealDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.revealPreviewIfNeeded()
            }
        }

        previewRevealTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func shouldRevealPreview(for type: CGEventType) -> Bool {
        guard !previewVisible else { return false }

        switch type {
        case .mouseMoved,
             .leftMouseDown,
             .leftMouseUp,
             .rightMouseDown,
             .rightMouseUp,
             .otherMouseDown,
             .otherMouseUp,
             .leftMouseDragged,
             .rightMouseDragged,
             .otherMouseDragged,
             .scrollWheel,
             .keyDown:
            return true
        default:
            return false
        }
    }

    private var overlayViews: [LockOverlayView] {
        overlayWindows.compactMap { $0.contentView as? LockOverlayView }
    }

    private func setOverlayWindowsLevel(_ level: NSWindow.Level) {
        overlayWindows.forEach { $0.level = level }
    }

    private func hideCursorIfNeeded() {
        guard !cursorHidden else { return }
        NSCursor.hide()
        cursorHidden = true
    }

    private func unhideCursorIfNeeded() {
        guard cursorHidden else { return }
        NSCursor.unhide()
        cursorHidden = false
    }

    private static var eventMask: CGEventMask {
        let eventTypes: [CGEventType] = [
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseUp,
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .scrollWheel,
            .keyDown,
            .keyUp,
            .flagsChanged
        ]

        var mask = eventTypes.reduce(into: CGEventMask(0)) { mask, type in
            mask |= CGEventMask(1) << type.rawValue
        }

        // NSSystemDefined (raw 14): brightness, volume and media keys.
        // No CGEventType case exists for it, so OR the bit in manually.
        mask |= CGEventMask(1) << 14

        return mask
    }
}
