import AppKit
import Carbon

/// Registers a single global hotkey via Carbon's EventHotKey API.
/// Carbon is Apple-deprecated in many places but the hotkey API is the
/// canonical macOS path for true global keys and remains supported.
@MainActor
final class HotkeyService {
    private static let signatureCode: OSType = 0x434C4344  // 'CLCD' = ClaudeDock
    private static let hotkeyID: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var onTrigger: (() -> Void)?

    func register(keyCode: UInt16, modifiers: UInt32, handler: @escaping () -> Void) {
        unregister()
        onTrigger = handler

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let svc = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in svc.onTrigger?() }
                return noErr
            },
            1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        var ref: EventHotKeyRef?
        let hkId = EventHotKeyID(signature: Self.signatureCode, id: Self.hotkeyID)
        RegisterEventHotKey(UInt32(keyCode), modifiers, hkId,
                            GetApplicationEventTarget(), 0, &ref)
        hotKeyRef = ref
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let h = eventHandlerRef { RemoveEventHandler(h); eventHandlerRef = nil }
        onTrigger = nil
    }

    /// Common modifier keyCode for Option (⌥). Modifier constants from Carbon: optionKey = 0x0800.
    static let optionKeyMask: UInt32 = 0x0800
    static let commandKeyMask: UInt32 = 0x0100
    static let controlKeyMask: UInt32 = 0x1000
    static let shiftKeyMask: UInt32 = 0x0200

    /// Sensible defaults — ⌥-Space.
    static let defaultKeyCode: UInt16 = 49  // kVK_Space
    static let defaultModifiers: UInt32 = optionKeyMask
}
