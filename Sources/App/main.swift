// Menu-bar app version: no Dock icon, a fader icon in the menu bar shows status and Quit.

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let statusLine = NSMenuItem(title: "S4 MK2：未連接", action: nil, keyEquivalent: "")
    private var bridge: Bridge?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "slider.vertical.3", accessibilityDescription: bridgeName)

        let menu = NSMenu()
        menu.addItem(statusLine)
        menu.addItem(NSMenuItem(title: "MIDI 輸出：\(bridgeName)，通道 \(midiChannel + 1)，CC 20–24", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "結束 \(bridgeName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        setConnected(false)

        do {
            let b = try Bridge()
            b.onConnectionChange = { [weak self] in self?.setConnected($0) }
            b.onLog = { NSLog("%@", $0) }
            try b.start()
            bridge = b
        } catch {
            let alert = NSAlert()
            alert.messageText = "\(bridgeName) 無法啟動"
            alert.informativeText = "\(error)"
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    private func setConnected(_ connected: Bool) {
        statusLine.title = connected ? "S4 MK2：已連接" : "S4 MK2：未連接"
        statusItem.button?.appearsDisabled = !connected
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
