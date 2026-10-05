import AppKit
import SwiftUI

/// Owns the desktop pet window: placement, dragging, and per-pixel click-through.
@MainActor
final class PetWindowController {
    private let panel: PetPanel
    private let artwork: PetArtwork
    private var dragOrigin: CGPoint?
    private var dragMouseStart: CGPoint?
    private var mouseMonitors: [Any] = []

    init(brain: CompanionBrain, artwork: PetArtwork? = nil) {
        let artwork = artwork ?? PetArtworkProvider.current
        self.artwork = artwork
        panel = PetPanel(size: artwork.size)

        let root = PetView(
            artwork: artwork,
            onDrag: { [weak self] in self?.drag() },
            onDragEnd: { [weak self] in self?.endDrag() },
            menu: {
                AnyView(Group {
                    Button("Hide Pet") { PetVisibility.isVisible = false }
                    Button("Quit Companion") { NSApp.terminate(nil) }
                })
            }
        )
        .environment(brain)

        let host = NSHostingView(rootView: root)
        host.frame = CGRect(origin: .zero, size: artwork.size)
        panel.contentView = host
        panel.setFrameOrigin(defaultOrigin())
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        panel.orderFrontRegardless()
        startClickThroughTracking()
    }

    func hide() {
        panel.orderOut(nil)
        stopClickThroughTracking()
    }

    // MARK: - Dragging

    /// Follows the mouse in screen coordinates; SwiftUI's gesture coordinates move with the window.
    private func drag() {
        let mouse = NSEvent.mouseLocation
        if dragOrigin == nil {
            dragOrigin = panel.frame.origin
            dragMouseStart = mouse
        }
        guard let origin = dragOrigin, let start = dragMouseStart else { return }
        panel.setFrameOrigin(CGPoint(x: origin.x + mouse.x - start.x, y: origin.y + mouse.y - start.y))
    }

    private func endDrag() {
        dragOrigin = nil
        dragMouseStart = nil
        panel.setFrameOrigin(clampedToScreen(panel.frame.origin))
    }

    // MARK: - Placement

    private func defaultOrigin() -> CGPoint {
        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        return CGPoint(x: visible.maxX - artwork.size.width - 40, y: visible.minY + 40)
    }

    private func clampedToScreen(_ origin: CGPoint) -> CGPoint {
        let frame = CGRect(origin: origin, size: artwork.size)
        let screen = NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return origin }
        return CGPoint(
            x: min(max(origin.x, visible.minX), visible.maxX - artwork.size.width),
            y: min(max(origin.y, visible.minY), visible.maxY - artwork.size.height)
        )
    }

    // MARK: - Click-through

    /// The window ignores the mouse except while the cursor is over the character itself.
    private func startClickThroughTracking() {
        guard mouseMonitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDown, .leftMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.updateClickThrough() }
        }) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.updateClickThrough() }
            return event
        }) {
            mouseMonitors.append(local)
        }
        updateClickThrough()
    }

    private func stopClickThroughTracking() {
        mouseMonitors.forEach(NSEvent.removeMonitor)
        mouseMonitors.removeAll()
    }

    private func updateClickThrough() {
        if dragOrigin != nil { panel.ignoresMouseEvents = false; return }
        let mouse = NSEvent.mouseLocation
        let frame = panel.frame
        let local = CGPoint(x: mouse.x - frame.minX, y: frame.maxY - mouse.y)
        panel.ignoresMouseEvents = !artwork.contains(local)
    }
}

/// Whether the pet is shown; persisted and observed by the app.
enum PetVisibility {
    static let key = "petVisible"

    static var isVisible: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
