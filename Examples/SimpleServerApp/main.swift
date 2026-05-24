import AppKit
import Foundation
import Metal
import MetalKit
import Syphon26
import Syphon26SimpleUIShared

private struct LaunchOptions {
    var machServiceName = Syphon26.defaultControlPlaneMachServiceName
    var streamName = "Syphon26 Simple Server"
    var autoStart = false
}

private func parseLaunchOptions() -> LaunchOptions {
    var options = LaunchOptions()
    var arguments = Array(CommandLine.arguments.dropFirst())
    while !arguments.isEmpty {
        let key = arguments.removeFirst()
        switch key {
        case "--auto-start":
            options.autoStart = true
        case "--mach-service":
            guard !arguments.isEmpty else { continue }
            options.machServiceName = arguments.removeFirst()
        case "--name", "--stream-name":
            guard !arguments.isEmpty else { continue }
            options.streamName = arguments.removeFirst()
        default:
            continue
        }
    }
    return options
}

@MainActor
private final class MeterView: NSView {
    var value: Double = 0 {
        didSet { needsDisplay = true }
    }

    var tintColor: NSColor = .systemGreen {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        let clamped = min(max(value, 0), 1)
        let activeRect = NSRect(x: 0, y: 0, width: bounds.width * clamped, height: bounds.height)
        tintColor.setFill()
        activeRect.fill()
    }
}

@MainActor
private final class ServerAppDelegate: NSObject, NSApplicationDelegate {
    private let launchOptions: LaunchOptions
    private var window: NSWindow?
    private var device: (any MTLDevice)?
    private var commandQueue: (any MTLCommandQueue)?
    private var previewRenderer: Syphon26PreviewRenderer?
    private var controlPlane: Syphon26ControlPlane?
    private var server: Syphon26Server?
    private var renderTimer: Timer?
    private var metricsTimer: Timer?
    private var frameIndex = 0
    private var lastPublishedFrames: UInt64 = 0
    private var lastMetricsTime = Date()
    private var currentTargetFPS = 60.0
    private var currentWidth = 1920
    private var currentHeight = 1080

    private let serviceField = NSTextField(string: Syphon26.defaultControlPlaneMachServiceName)
    private let streamNameField = NSTextField(string: "Syphon26 Simple Server")
    private let resolutionModePopup = NSPopUpButton()
    private let resolutionPresetPopup = NSPopUpButton()
    private let widthField = NSTextField(string: "1920")
    private let heightField = NSTextField(string: "1080")
    private let fpsModePopup = NSPopUpButton()
    private let fpsPresetPopup = NSPopUpButton()
    private let fpsField = NSTextField(string: "60")
    private let pixelFormatPopup = NSPopUpButton()
    private let startStopButton = NSButton(title: "Start", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "Stopped")
    private let streamIDLabel = NSTextField(labelWithString: "-")
    private let outputLabel = NSTextField(labelWithString: "1920x1080 BGRA8")
    private let targetFPSLabel = NSTextField(labelWithString: "60 fps")
    private let actualFPSLabel = NSTextField(labelWithString: "0 fps")
    private let publishedLabel = NSTextField(labelWithString: "0")
    private let clientsLabel = NSTextField(labelWithString: "0")
    private let syncLabel = NSTextField(labelWithString: "-")
    private let diagnosticsLabel = NSTextField(labelWithString: "-")
    private let errorLabel = NSTextField(labelWithString: "")
    private let meterView = MeterView(frame: NSRect(x: 0, y: 0, width: 360, height: 14))
    private let previewView = MTKView(frame: NSRect(x: 0, y: 0, width: 640, height: 360))

    init(options: LaunchOptions) {
        self.launchOptions = options
        super.init()
        serviceField.stringValue = options.machServiceName
        streamNameField.stringValue = options.streamName
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = notification
        fputs("Syphon26SimpleServerApp launching\n", stderr)
        setupMenu()
        buildWindow()
        setupMetal()
        updateControlAvailability()
        if launchOptions.autoStart {
            startServer()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        _ = notification
        stopServer()
    }

    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            setError("Metal device or command queue is unavailable.")
            return
        }
        self.device = device
        self.commandQueue = queue
        do {
            let renderer = try Syphon26PreviewRenderer(device: device)
            renderer.configurePreviewView(previewView)
            self.previewRenderer = renderer
        } catch {
            setError("Preview renderer unavailable: \(error)")
        }
    }

    private func setupMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit Syphon26 Server", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        NSApplication.shared.mainMenu = mainMenu
    }

    private func buildWindow() {
        configurePopups()

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Syphon26 Simple Server")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        root.addArrangedSubview(title)

        root.addArrangedSubview(row("Control Plane", [serviceField]))
        root.addArrangedSubview(row("Stream Name", [streamNameField]))
        root.addArrangedSubview(row("Resolution", [resolutionModePopup, resolutionPresetPopup, widthField, label("W"), heightField, label("H")]))
        root.addArrangedSubview(row("Frame Rate", [fpsModePopup, fpsPresetPopup, fpsField, label("fps")]))
        root.addArrangedSubview(row("Pixel Format", [pixelFormatPopup]))
        root.addArrangedSubview(previewSection())

        startStopButton.target = self
        startStopButton.action = #selector(toggleServer)
        root.addArrangedSubview(row("Transport", [startStopButton, statusLabel]))

        meterView.widthAnchor.constraint(equalToConstant: 360).isActive = true
        meterView.heightAnchor.constraint(equalToConstant: 14).isActive = true
        root.addArrangedSubview(row("Activity", [meterView, actualFPSLabel]))

        root.addArrangedSubview(row("Stream ID", [streamIDLabel]))
        root.addArrangedSubview(row("Output", [outputLabel]))
        root.addArrangedSubview(row("Target FPS", [targetFPSLabel]))
        root.addArrangedSubview(row("Published", [publishedLabel]))
        root.addArrangedSubview(row("Clients", [clientsLabel]))
        root.addArrangedSubview(row("Sync", [syncLabel]))
        diagnosticsLabel.lineBreakMode = .byTruncatingTail
        diagnosticsLabel.widthAnchor.constraint(equalToConstant: 520).isActive = true
        root.addArrangedSubview(row("Diagnostics", [diagnosticsLabel]))
        errorLabel.textColor = .systemRed
        errorLabel.lineBreakMode = .byTruncatingTail
        errorLabel.widthAnchor.constraint(equalToConstant: 640).isActive = true
        root.addArrangedSubview(row("Status Detail", [errorLabel]))

        let content = NSView()
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 80, y: 80, width: 820, height: 920),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Syphon26 Simple Server"
        window.contentView = content
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private func configurePopups() {
        resolutionModePopup.addItems(withTitles: ["Auto display", "Manual"])
        resolutionModePopup.target = self
        resolutionModePopup.action = #selector(settingsChanged)

        resolutionPresetPopup.addItems(withTitles: ["1280x720", "1920x1080", "3840x2160", "Custom"])
        resolutionPresetPopup.selectItem(withTitle: "1920x1080")
        resolutionPresetPopup.target = self
        resolutionPresetPopup.action = #selector(resolutionPresetChanged)

        fpsModePopup.addItems(withTitles: ["Auto display", "Manual"])
        fpsModePopup.target = self
        fpsModePopup.action = #selector(settingsChanged)

        fpsPresetPopup.addItems(withTitles: ["30", "60", "120", "240", "Custom"])
        fpsPresetPopup.selectItem(withTitle: "60")
        fpsPresetPopup.target = self
        fpsPresetPopup.action = #selector(fpsPresetChanged)

        pixelFormatPopup.addItems(withTitles: ["BGRA8", "RGBA16F"])
    }

    private func row(_ title: String, _ views: [NSView]) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        let titleField = label(title)
        titleField.alignment = .right
        titleField.widthAnchor.constraint(equalToConstant: 110).isActive = true
        row.addArrangedSubview(titleField)

        for view in views {
            if view === serviceField || view === streamNameField {
                view.widthAnchor.constraint(equalToConstant: 360).isActive = true
            } else if view === widthField || view === heightField || view === fpsField {
                view.widthAnchor.constraint(equalToConstant: 72).isActive = true
            }
            row.addArrangedSubview(view)
        }
        return row
    }

    private func previewSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 6

        let title = label("Preview")
        title.alignment = .left
        previewView.widthAnchor.constraint(equalToConstant: 640).isActive = true
        previewView.heightAnchor.constraint(equalToConstant: 360).isActive = true

        section.addArrangedSubview(title)
        section.addArrangedSubview(previewView)
        return section
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 12, weight: .medium)
        return field
    }

    @objc private func settingsChanged() {
        updateControlAvailability()
    }

    @objc private func resolutionPresetChanged() {
        switch resolutionPresetPopup.titleOfSelectedItem {
        case "1280x720":
            widthField.stringValue = "1280"
            heightField.stringValue = "720"
        case "1920x1080":
            widthField.stringValue = "1920"
            heightField.stringValue = "1080"
        case "3840x2160":
            widthField.stringValue = "3840"
            heightField.stringValue = "2160"
        default:
            break
        }
        resolutionModePopup.selectItem(withTitle: "Manual")
        updateControlAvailability()
    }

    @objc private func fpsPresetChanged() {
        if fpsPresetPopup.titleOfSelectedItem != "Custom" {
            fpsField.stringValue = fpsPresetPopup.titleOfSelectedItem ?? "60"
        }
        fpsModePopup.selectItem(withTitle: "Manual")
        updateControlAvailability()
    }

    private func updateControlAvailability() {
        let manualResolution = resolutionModePopup.titleOfSelectedItem == "Manual"
        resolutionPresetPopup.isEnabled = manualResolution && server == nil
        widthField.isEnabled = manualResolution && server == nil
        heightField.isEnabled = manualResolution && server == nil

        let manualFPS = fpsModePopup.titleOfSelectedItem == "Manual"
        fpsPresetPopup.isEnabled = manualFPS && server == nil
        fpsField.isEnabled = manualFPS && server == nil

        serviceField.isEnabled = server == nil
        streamNameField.isEnabled = server == nil
        pixelFormatPopup.isEnabled = server == nil
    }

    @objc private func toggleServer() {
        if server == nil {
            startServer()
        } else {
            stopServer()
        }
    }

    private func startServer() {
        guard let device, let commandQueue else {
            setError("Metal device is unavailable.")
            return
        }
        guard previewRenderer != nil else {
            setError("Preview renderer is unavailable.")
            return
        }

        do {
            let size = resolvedResolution()
            let fps = resolvedFPS()
            let pixelFormat = selectedPixelFormat()
            let controlPlane = Syphon26ControlPlane(machServiceName: serviceField.stringValue)
            let server = try Syphon26Server(
                configuration: Syphon26ServerConfiguration(
                    name: streamNameField.stringValue.isEmpty ? "Syphon26 Simple Server" : streamNameField.stringValue,
                    appName: "Syphon26SimpleServerApp",
                    device: device,
                    width: size.width,
                    height: size.height,
                    pixelFormat: pixelFormat,
                    syncMode: .automatic,
                    controlPlane: controlPlane
                )
            )
            try server.start()

            self.controlPlane = controlPlane
            self.server = server
            self.currentWidth = size.width
            self.currentHeight = size.height
            self.currentTargetFPS = fps
            self.frameIndex = 0
            self.lastPublishedFrames = 0
            self.lastMetricsTime = Date()
            self.commandQueue = commandQueue

            startStopButton.title = "Stop"
            statusLabel.stringValue = "Running"
            statusLabel.textColor = .systemGreen
            streamIDLabel.stringValue = server.streamID
            outputLabel.stringValue = "\(size.width)x\(size.height) \(pixelFormatLabel(pixelFormat))"
            targetFPSLabel.stringValue = String(format: "%.0f fps", fps)
            setError("")
            updateControlAvailability()
            startTimers(fps: fps)
            fputs(
                "Syphon26SimpleServerApp started streamID=\(server.streamID) name=\"\(server.name)\" size=\(size.width)x\(size.height) fps=\(String(format: "%.1f", fps))\n",
                stderr
            )
        } catch {
            setError("Start failed: \(error)")
            fputs("Syphon26SimpleServerApp start failed: \(error)\n", stderr)
        }
    }

    private func stopServer() {
        renderTimer?.invalidate()
        metricsTimer?.invalidate()
        renderTimer = nil
        metricsTimer = nil
        server?.stop()
        server = nil
        controlPlane = nil
        startStopButton.title = "Start"
        statusLabel.stringValue = "Stopped"
        statusLabel.textColor = .labelColor
        streamIDLabel.stringValue = "-"
        meterView.value = 0
        actualFPSLabel.stringValue = "0 fps"
        previewRenderer?.clear(previewView, commandQueue: commandQueue)
        updateControlAvailability()
        fputs("Syphon26SimpleServerApp stopped\n", stderr)
    }

    private func startTimers(fps: Double) {
        let interval = 1.0 / max(fps, 1.0)
        let renderTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.renderFrame()
            }
        }
        RunLoop.main.add(renderTimer, forMode: .common)
        self.renderTimer = renderTimer

        let metricsTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }
        RunLoop.main.add(metricsTimer, forMode: .common)
        self.metricsTimer = metricsTimer
    }

    private func renderFrame() {
        guard let server, let commandQueue, let previewRenderer else {
            return
        }
        do {
            let drawable = try server.acquireDrawable()
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                throw Syphon26Error.commandBufferRequired
            }
            let pixelFormat = selectedPixelFormat()
            try previewRenderer.renderPattern(
                into: drawable.texture,
                commandBuffer: commandBuffer,
                frameIndex: frameIndex,
                sourcePixelFormat: pixelFormat
            )
            try previewRenderer.renderPattern(
                to: previewView,
                commandBuffer: commandBuffer,
                frameIndex: frameIndex,
                sourcePixelFormat: pixelFormat,
                width: currentWidth,
                height: currentHeight
            )
            try server.presentDrawable(drawable, commandBuffer: commandBuffer)
            commandBuffer.commit()
            frameIndex += 1
        } catch {
            setError("Publish failed: \(error)")
        }
    }

    private func updateMetrics() {
        guard let server else {
            return
        }
        let diagnostics = server.diagnosticsSnapshot()
        let now = Date()
        let elapsed = max(now.timeIntervalSince(lastMetricsTime), 0.001)
        let frameDelta = diagnostics.publishedFrames >= lastPublishedFrames
            ? diagnostics.publishedFrames - lastPublishedFrames
            : 0
        let actualFPS = Double(frameDelta) / elapsed
        let xpcClientCount: Int
        if let controlPlane {
            xpcClientCount = (try? controlPlane.activeConsumerCount(streamID: server.streamID)) ?? diagnostics.activeClientCount
        } else {
            xpcClientCount = diagnostics.activeClientCount
        }
        let activeClientCount = max(diagnostics.activeClientCount, xpcClientCount)

        lastPublishedFrames = diagnostics.publishedFrames
        lastMetricsTime = now

        let ratio = actualFPS / max(currentTargetFPS, 1.0)
        meterView.value = min(ratio, 1)
        meterView.tintColor = ratio >= 0.95 ? .systemGreen : (ratio >= 0.75 ? .systemYellow : .systemRed)
        actualFPSLabel.stringValue = String(format: "%.1f fps", actualFPS)
        publishedLabel.stringValue = "\(diagnostics.publishedFrames)"
        clientsLabel.stringValue = "\(activeClientCount)"
        syncLabel.stringValue = "\(diagnostics.syncMode) fallback=\(diagnostics.fallbackReason)"
        diagnosticsLabel.stringValue = "xpcConsumers=\(xpcClientCount) overwritten=\(diagnostics.overwrittenFrames) stalls=\(diagnostics.producerStallNanoseconds / 1_000_000)ms sharedSignals=\(diagnostics.sharedEventSignals)"
        if launchOptions.autoStart {
            fputs(
                "Syphon26SimpleServerApp metrics published=\(diagnostics.publishedFrames) clients=\(activeClientCount) fps=\(String(format: "%.1f", actualFPS)) sync=\(diagnostics.syncMode) fallback=\(diagnostics.fallbackReason)\n",
                stderr
            )
        }
    }

    private func resolvedResolution() -> (width: Int, height: Int) {
        if resolutionModePopup.titleOfSelectedItem == "Auto display",
           let screen = NSScreen.main ?? NSScreen.screens.first {
            let scale = screen.backingScaleFactor
            let width = max(64, Int((screen.frame.width * scale).rounded()))
            let height = max(64, Int((screen.frame.height * scale).rounded()))
            return (width, height)
        }
        let width = clamp(Int(widthField.stringValue) ?? 1920, min: 64, max: 8192)
        let height = clamp(Int(heightField.stringValue) ?? 1080, min: 64, max: 8192)
        return (width, height)
    }

    private func resolvedFPS() -> Double {
        if fpsModePopup.titleOfSelectedItem == "Auto display" {
            let value = NSScreen.main?.maximumFramesPerSecond ?? 60
            return Double(value > 0 ? value : 60)
        }
        return min(max(Double(fpsField.stringValue) ?? 60, 1), 240)
    }

    private func selectedPixelFormat() -> MTLPixelFormat {
        pixelFormatPopup.titleOfSelectedItem == "RGBA16F" ? .rgba16Float : .bgra8Unorm
    }

    private func pixelFormatLabel(_ pixelFormat: MTLPixelFormat) -> String {
        pixelFormat == .rgba16Float ? "RGBA16F" : "BGRA8"
    }

    private func clamp(_ value: Int, min minValue: Int, max maxValue: Int) -> Int {
        Swift.min(Swift.max(value, minValue), maxValue)
    }

    private func setError(_ message: String) {
        errorLabel.stringValue = message.isEmpty ? "OK" : message
        errorLabel.textColor = message.isEmpty ? .secondaryLabelColor : .systemRed
        if launchOptions.autoStart, !message.isEmpty {
            fputs("Syphon26SimpleServerApp status: \(message)\n", stderr)
        }
    }

}

let app = NSApplication.shared
private let delegate = ServerAppDelegate(options: parseLaunchOptions())
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
