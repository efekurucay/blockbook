import AppKit

struct LockConfiguration {
    let unlockPassword: String
    let unlockShortcut: UnlockShortcut
    let changeImageShortcut: UnlockShortcut
    let previewRevealDelay: TimeInterval
    let unlockTitle: String
    let unlockMessage: String
    let invalidPasswordMessage: String
    let imagePickerTitle: String
    let imagePickerMessage: String

    static let `default` = LockConfiguration(
        unlockPassword: "1234",
        unlockShortcut: .commandE,
        changeImageShortcut: .commandR,
        previewRevealDelay: 1.5,
        unlockTitle: "Kilidi Ac",
        unlockMessage: "Devam etmek icin parolayi girin.",
        invalidPasswordMessage: "Parola yanlis. Tekrar deneyin.",
        imagePickerTitle: "Gorsel Sec",
        imagePickerMessage: "Kilitte gosterilecek gorseli secin veya degistirin."
    )
}

struct UnlockShortcut: Sendable {
    let keyCode: Int64
    let requiredModifiers: NSEvent.ModifierFlags

    static let commandE = UnlockShortcut(
        keyCode: 14,
        requiredModifiers: [.command]
    )

    static let commandR = UnlockShortcut(
        keyCode: 15,
        requiredModifiers: [.command]
    )

    func matches(keyCode: Int64, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        keyCode == self.keyCode && normalized(modifierFlags) == requiredModifiers
    }

    private func normalized(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection([.command, .control, .option, .shift])
    }
}
