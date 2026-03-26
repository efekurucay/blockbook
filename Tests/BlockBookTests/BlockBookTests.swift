import AppKit
import Foundation
import Testing
@testable import BlockBook

@Test func unlockShortcutMatchesCommandEOnly() {
    #expect(UnlockShortcut.commandE.matches(keyCode: 14, modifierFlags: [.command]))
    #expect(!UnlockShortcut.commandE.matches(keyCode: 14, modifierFlags: [.command, .shift]))
    #expect(!UnlockShortcut.commandE.matches(keyCode: 8, modifierFlags: [.command]))
}

@Test func changeImageShortcutMatchesCommandROnly() {
    #expect(UnlockShortcut.commandR.matches(keyCode: 15, modifierFlags: [.command]))
    #expect(!UnlockShortcut.commandR.matches(keyCode: 15, modifierFlags: [.command, .option]))
    #expect(!UnlockShortcut.commandR.matches(keyCode: 14, modifierFlags: [.command]))
}

@Test func imageStoreCopiesSelectedImageIntoStoreDirectory() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceURL = rootURL.appendingPathComponent("source.png")
    let storeURL = rootURL.appendingPathComponent("store", isDirectory: true)

    try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: rootURL) }

    let image = NSImage(size: NSSize(width: 12, height: 12))
    image.lockFocus()
    NSColor.systemRed.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 12, height: 12)).fill()
    image.unlockFocus()

    let tiffData = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiffData))
    let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
    try pngData.write(to: sourceURL)

    let store = try LockImageStore(baseURL: storeURL)
    let storedURL = try store.storeImage(from: sourceURL)

    #expect(storedURL.deletingLastPathComponent().standardizedFileURL == storeURL.standardizedFileURL)
    #expect(store.storedImageURL()?.standardizedFileURL == storedURL.standardizedFileURL)
    #expect(store.loadImage() != nil)
}
