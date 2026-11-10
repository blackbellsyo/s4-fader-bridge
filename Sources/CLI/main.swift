// Command-line version.
//   s4bridge          send MIDI and print each CC
//   s4bridge --dump   print changed HID report bytes (no MIDI)

import Foundation

setvbuf(stdout, nil, _IOLBF, 0)
let dump = CommandLine.arguments.contains("--dump")

do {
    let bridge = try Bridge(dumpMode: dump)
    bridge.onLog = { print($0) }
    try bridge.start()
    print("\(bridgeName) running (non-exclusive HID, MIDI ch \(midiChannel + 1), CC 20-24)\(dump ? " [dump mode]" : ""). Ctrl+C to quit.")
    withExtendedLifetime(bridge) { CFRunLoopRun() }
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
