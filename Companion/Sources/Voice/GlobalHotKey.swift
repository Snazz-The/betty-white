import Carbon.HIToolbox
import Foundation

/// A system-wide hotkey with press and release callbacks, via Carbon's RegisterEventHotKey.
/// Works in the sandbox and needs no Accessibility permission.
@MainActor
final class GlobalHotKey {
    var onPress: (@MainActor () -> Void)?
    var onRelease: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private static let signature: OSType = 0x434D_504E // "CMPN"

    @discardableResult
    func register(_ combo: HotKeyCombo) -> Bool {
        unregister()
        installHandlerIfNeeded()
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        return RegisterEventHotKey(combo.keyCode, combo.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef) == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, types.count, &types, context, &handlerRef)
    }

    fileprivate func handle(pressed: Bool) {
        if pressed { onPress?() } else { onRelease?() }
    }
}

/// Carbon callback; a free function so it can be passed as a C function pointer.
private func hotKeyEventHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ context: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let context else { return OSStatus(eventNotHandledErr) }
    let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
    let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor in hotKey.handle(pressed: pressed) }
    return noErr
}
