import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let lockController = LockController(configuration: .default)

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AccessibilityAuthorizer.isTrusted(prompt: true) else {
            presentError(
                title: "Accessibility izni gerekli",
                message: """
                BlockBook klavye ve mouse girisini kilitlemek icin Accessibility iznine ihtiyac duyar.

                System Settings > Privacy & Security > Accessibility ekraninda BlockBook'u etkinlestirin, sonra uygulamayi yeniden acin.
                """
            )
            NSApp.terminate(nil)
            return
        }

        do {
            try lockController.activate()
        } catch {
            presentError(
                title: "Kilit etkinlestirilemedi",
                message: error.localizedDescription
            )
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        lockController.deactivate()
    }

    private func presentError(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Tamam")
        alert.runModal()
    }
}
