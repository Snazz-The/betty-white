import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click, then press a key combination (with at least one modifier). Esc cancels.
struct HotKeyRecorder: View {
    @Binding var combo: HotKeyCombo
    /// Told when recording starts and stops, so the live hotkey can step aside.
    var onRecordingChanged: (Bool) -> Void = { _ in }
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "Press keys…" : combo.displayString)
                .monospaced()
                .frame(minWidth: 110)
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        onRecordingChanged(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stop()
                return nil
            }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let candidate = HotKeyCombo(keyCode: event.keyCode, modifierFlags: flags)
            guard candidate.hasModifier else {
                NSSound.beep()
                return nil
            }
            combo = candidate
            stop()
            return nil
        }
    }

    private func stop() {
        guard recording else { return }
        recording = false
        onRecordingChanged(false)
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
