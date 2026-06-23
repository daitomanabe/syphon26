import AppKit
import Foundation

@MainActor
public final class Syphon26PassivePreviewWindow: NSWindow {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

@MainActor
public final class Syphon26SampleAppDelegate: NSObject, NSApplicationDelegate {
    private let title: String
    private let result: Syphon26SampleRunResult
    private var window: Syphon26PassivePreviewWindow?

    public init(title: String, result: Syphon26SampleRunResult) {
        self.title = title
        self.result = result
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let window = makeWindow(title: title, result: result)
        self.window = window
        window.orderBack(nil)
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@MainActor
public func passivePreviewWindowSmokeJSON(title: String) throws -> String {
    let result = Syphon26SampleRunResult(
        role: title,
        transportScope: "appkit-passive-preview",
        controlPlaneState: "notStarted",
        streamID: "preview-window-smoke",
        width: 640,
        height: 360,
        pixelFormat: "bgra8Unorm",
        expectedFrames: 0,
        publishedFrames: 0,
        receivedFrames: 0,
        missedFrames: 0,
        repeatedReads: 0,
        overwrittenFrames: 0,
        registeredStreamCount: 0,
        registeredConsumerCount: 0,
        textureOpened: false
    )
    let window = makeWindow(title: title, result: result)
    let payload: [String: Any] = [
        "title": title,
        "canBecomeKey": window.canBecomeKey,
        "canBecomeMain": window.canBecomeMain,
        "isKeyWindow": window.isKeyWindow,
        "isMainWindow": window.isMainWindow,
        "status": "ok"
    ]
    let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    return String(decoding: data, as: UTF8.self)
}

@MainActor
private func makeWindow(title: String, result: Syphon26SampleRunResult) -> Syphon26PassivePreviewWindow {
    let window = Syphon26PassivePreviewWindow(
        contentRect: NSRect(x: 100, y: 100, width: 640, height: 360),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.title = title
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.contentView = Syphon26SampleDiagnosticsView(result: result)
    return window
}

@MainActor
private final class Syphon26SampleDiagnosticsView: NSView {
    private let result: Syphon26SampleRunResult

    init(result: Syphon26SampleRunResult) {
        self.result = result
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1).cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let text = """
        \(result.role)
        stream \(result.streamID)
        published \(result.publishedFrames) received \(result.receivedFrames)
        scope \(result.transportScope)
        """
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular),
            .foregroundColor: NSColor.white
        ]
        text.draw(in: bounds.insetBy(dx: 24, dy: 24), withAttributes: attributes)
    }
}
