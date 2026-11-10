// Bridge.swift — Traktor Kontrol S4 MK2 channel faders -> virtual CoreMIDI port.
//
// Read-only: opens the S4's HID interface NON-exclusively (kIOHIDOptionsTypeNone)
// and never sends output reports, so NIHardwareAgent / Traktor keep working.

import Foundation
import IOKit.hid
import CoreMIDI

let bridgeName = "S4 Fader Bridge"
let vendorID = 0x17CC   // Native Instruments
let productID = 0x1310  // Traktor Kontrol S4 MK2
let midiChannel: UInt8 = 15  // 0-based: 15 = MIDI channel 16

// (name, byte offset of little-endian UInt16 in report 0x02 incl. report-ID byte, CC number)
// Offsets from Mixxx's Traktor-Kontrol-S4-MK2-hid-scripts.js, confirmed on hardware with --dump.
let controls: [(name: String, offset: Int, cc: UInt8)] = [
    ("Fader A", 0x37, 20),
    ("Fader B", 0x39, 21),
    ("Fader C", 0x3B, 22),
    ("Fader D", 0x3D, 23),
    ("Crossfader", 0x07, 24),
]
let rawMin = 16, rawMax = 4080  // values outside are clamped to 0 / 127

struct BridgeError: Error, CustomStringConvertible {
    let description: String
}

final class Bridge {
    /// Called on the main run loop when the S4 MK2 is connected (true) or removed (false).
    var onConnectionChange: ((Bool) -> Void)?
    /// Called for every log line (CC sent, dump output, errors).
    var onLog: ((String) -> Void)?

    private let dumpMode: Bool
    private var midiClient = MIDIClientRef()
    private var midiSource = MIDIEndpointRef()
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var previous = [UInt32: [UInt8]]()
    private var lastValue = [UInt8: UInt8]()
    private var lastRaw = [UInt8: Int]()

    init(dumpMode: Bool = false) throws {
        self.dumpMode = dumpMode
        var status = MIDIClientCreateWithBlock(bridgeName as CFString, &midiClient, nil)
        guard status == noErr else { throw BridgeError(description: "MIDIClientCreate failed: \(status)") }
        status = MIDISourceCreateWithProtocol(midiClient, bridgeName as CFString, ._1_0, &midiSource)
        guard status == noErr else { throw BridgeError(description: "MIDISourceCreate failed: \(status)") }
    }

    func start() throws {
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: vendorID, kIOHIDProductIDKey: productID] as CFDictionary)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, _ in
            Unmanaged<Bridge>.fromOpaque(ctx!).takeUnretainedValue().connectionChanged(true)
        }, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, _ in
            Unmanaged<Bridge>.fromOpaque(ctx!).takeUnretainedValue().connectionChanged(false)
        }, ctx)
        IOHIDManagerRegisterInputReportCallback(manager, { ctx, _, _, _, reportID, report, length in
            Unmanaged<Bridge>.fromOpaque(ctx!).takeUnretainedValue()
                .handle(reportID: reportID, bytes: Array(UnsafeBufferPointer(start: report, count: length)))
        }, ctx)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        // kIOHIDOptionsTypeNone = shared access. NEVER use kIOHIDOptionsTypeSeizeDevice: it would cut off Traktor.
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            throw BridgeError(description: String(format: "IOHIDManagerOpen failed: 0x%08X", result))
        }
    }

    private func connectionChanged(_ connected: Bool) {
        if !connected { lastValue.removeAll(); lastRaw.removeAll(); previous.removeAll() }
        onLog?(connected ? "S4 MK2 connected" : "S4 MK2 disconnected")
        onConnectionChange?(connected)
    }

    private func sendCC(_ cc: UInt8, _ value: UInt8) {
        // UMP MIDI 1.0 channel voice message, group 0
        var word: UInt32 = 0x2000_0000 | UInt32(0xB0 | midiChannel) << 16 | UInt32(cc) << 8 | UInt32(value)
        var list = MIDIEventList()
        withUnsafeMutablePointer(to: &list) { p in
            let pkt = MIDIEventListInit(p, ._1_0)
            _ = MIDIEventListAdd(p, MemoryLayout<MIDIEventList>.size, pkt, 0, 1, &word)
            let status = MIDIReceivedEventList(midiSource, p)
            if status != noErr { onLog?("MIDIReceivedEventList failed: \(status)") }
        }
    }

    private func handle(reportID: UInt32, bytes: [UInt8]) {
        if dumpMode {
            if let prev = previous[reportID], prev.count == bytes.count {
                let diffs = bytes.indices.filter { bytes[$0] != prev[$0] }
                    .map { String(format: "[0x%02X] %02X->%02X", $0, prev[$0], bytes[$0]) }
                if !diffs.isEmpty { onLog?("id=\(reportID) len=\(bytes.count) " + diffs.joined(separator: " ")) }
            } else {
                onLog?("id=\(reportID) len=\(bytes.count) first byte=\(String(format: "0x%02X", bytes.first ?? 0)) (first report)")
            }
            previous[reportID] = bytes
            return
        }

        guard reportID == 0x02, bytes.count >= 0x3F, bytes[0] == 0x02 else { return }
        for c in controls {
            let raw = Int(bytes[c.offset]) | Int(bytes[c.offset + 1]) << 8
            let scaled = (raw - rawMin) * 127 + (rawMax - rawMin) / 2
            let v = UInt8(max(0, min(127, scaled / (rawMax - rawMin))))
            guard lastValue[c.cc] != v else { continue }
            // Hysteresis against ADC jitter; endpoints always pass so 0 and 127 stay reachable.
            if let lr = lastRaw[c.cc], abs(raw - lr) < 12, v != 0, v != 127 { continue }
            lastValue[c.cc] = v
            lastRaw[c.cc] = raw
            sendCC(c.cc, v)
            onLog?("\(c.name): raw \(raw) -> CC\(c.cc) = \(v)")
        }
    }
}
