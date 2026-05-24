import AppKit
import Foundation
import Metal
import MetalKit
import Syphon26
import Syphon26SimpleUIShared

private struct LaunchOptions {
    var machServiceName = Syphon26.defaultControlPlaneMachServiceName
    var streamName: String?
    var autoConnect = false
}

private func parseLaunchOptions() -> LaunchOptions {
    var options = LaunchOptions()
    var arguments = Array(CommandLine.arguments.dropFirst())
    while !arguments.isEmpty {
        let key = arguments.removeFirst()
        switch key {
        case "--auto-connect":
            options.autoConnect = true
        case "--mach-service":
            guard !arguments.isEmpty else { continue }
            options.machServiceName = arguments.removeFirst()
        case "--stream-name", "--name":
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
private final class ClientAppDelegate: NSObject, NSApplicationDelegate {
    private let launchOptions: LaunchOptions
    private var window: NSWindow?
    private var device: (any MTLDevice)?
    private var commandQueue: (any MTLCommandQueue)?
    private var previewRenderer: Syphon26PreviewRenderer?
    private var controlPlane: Syphon26ControlPlane?
    private var client: Syphon26Client?
    private var streams: [Syphon26StreamDescription] = []
    private var pollTimer: (any DispatchSourceTimer)?
    private var metricsTimer: Timer?
    private var streamRefreshTimer: Timer?
    private var observedFrames: UInt64 = 0
    private var repeatedReads: UInt64 = 0
    private var lastObservedFrames: UInt64 = 0
    private var lastMetricsTime = Date()
    private var lastSequence: Syphon26Sequence = 0
    private var lastFrameWidth = 0
    private var lastFrameHeight = 0
    private var lastFrameFormat = "-"

    private let serviceField = NSTextField(string: Syphon26.defaultControlPlaneMachServiceName)
    private let streamPopup = NSPopUpButton()
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let resolutionModePopup = NSPopUpButton()
    private let widthField = NSTextField(string: "1920")
    private let heightField = NSTextField(string: "1080")
    private let fpsModePopup = NSPopUpButton()
    private let fpsField = NSTextField(string: "60")
    private let pixelFormatPopup = NSPopUpButton()
    private let connectButton = NSButton(title: "Connect", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "Disconnected")
    private let streamIDLabel = NSTextField(labelWithString: "-")
    private let sourceLabel = NSTextField(labelWithString: "-")
    private let frameLabel = NSTextField(labelWithString: "-")
    private let expectedLabel = NSTextField(labelWithString: "-")
    private let fpsLabel = NSTextField(labelWithString: "0 fps")
    private let observedLabel = NSTextField(labelWithString: "0")
    private let repeatedLabel = NSTextField(labelWithString: "0")
    private let sequenceLabel = NSTextField(labelWithString: "0")
    private let syncLabel = NSTextField(labelWithString: "-")
    private let diagnosticsLabel = NSTextField(labelWithString: "-")
    private let errorLabel = NSTextField(labelWithString: "")
    private let meterView = MeterView(frame: NSRect(x: 0, y: 0, width: 360, height: 14))
    private let previewView = MTKView(frame: NSRect(x: 0, y: 0, width: 640, height: 360))

    init(options: LaunchOptions) {
        self.launchOptions = options
        super.init()
        serviceField.stringValue = options.machServiceName
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = notification
        fputs("Syphon26SimpleClientApp launching\n", stderr)
        setupMenu()
        buildWindow()
        setupMetal()
        refreshStreams(selectName: launchOptions.streamName)
        startStreamRefreshTimer()
        updateControlAvailability()
        maybeAutoConnect()
    }

    func applicationWillTerminate(_ notification: Notification) {
        _ = notification
        disconnect()
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
        appMenu.addItem(NSMenuItem(title: "Quit Syphon26 Client", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
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

        let title = NSTextField(labelWithString: "Syphon26 Simple Client")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        root.addArrangedSubview(title)

        root.addArrangedSubview(row("Control Plane", [serviceField]))
        refreshButton.target = self
        refreshButton.action = #selector(refreshPressed)
        root.addArrangedSubview(row("Server", [streamPopup, refreshButton]))
        root.addArrangedSubview(row("Resolution", [resolutionModePopup, widthField, label("W"), heightField, label("H")]))
        root.addArrangedSubview(row("Frame Rate", [fpsModePopup, fpsField, label("fps target")]))
        root.addArrangedSubview(row("Pixel Format", [pixelFormatPopup]))
        root.addArrangedSubview(previewSection())

        connectButton.target = self
        connectButton.action = #selector(toggleConnection)
        root.addArrangedSubview(row("Transport", [connectButton, statusLabel]))

        meterView.widthAnchor.constraint(equalToConstant: 360).isActive = true
        meterView.heightAnchor.constraint(equalToConstant: 14).isActive = true
        root.addArrangedSubview(row("Activity", [meterView, fpsLabel]))

        root.addArrangedSubview(row("Stream ID", [streamIDLabel]))
        root.addArrangedSubview(row("Source", [sourceLabel]))
        root.addArrangedSubview(row("Frame", [frameLabel]))
        root.addArrangedSubview(row("Expected", [expectedLabel]))
        root.addArrangedSubview(row("Observed", [observedLabel]))
        root.addArrangedSubview(row("Repeated", [repeatedLabel]))
        root.addArrangedSubview(row("Sequence", [sequenceLabel]))
        root.addArrangedSubview(row("Sync", [syncLabel]))
        diagnosticsLabel.lineBreakMode = .byTruncatingTail
        diagnosticsLabel.widthAnchor.constraint(equalToConstant: 560).isActive = true
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
            contentRect: NSRect(x: 120, y: 120, width: 860, height: 980),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Syphon26 Simple Client"
        window.contentView = content
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private func configurePopups() {
        streamPopup.widthAnchor.constraint(equalToConstant: 500).isActive = true
        streamPopup.target = self
        streamPopup.action = #selector(streamSelectionChanged)

        resolutionModePopup.addItems(withTitles: ["Auto from stream", "Manual expected"])
        resolutionModePopup.target = self
        resolutionModePopup.action = #selector(settingsChanged)

        fpsModePopup.addItems(withTitles: ["Auto observe", "Manual expected"])
        fpsModePopup.target = self
        fpsModePopup.action = #selector(settingsChanged)

        pixelFormatPopup.addItems(withTitles: ["Auto preferred", "BGRA8", "RGBA16F"])
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
            if view === serviceField {
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

    @objc private func refreshPressed() {
        refreshStreams(selectName: nil)
    }

    @objc private func settingsChanged() {
        updateControlAvailability()
        updateSelectedStreamLabels()
    }

    @objc private func streamSelectionChanged() {
        updateSelectedStreamLabels()
    }

    @objc private func toggleConnection() {
        if client == nil {
            connect()
        } else {
            disconnect()
        }
    }

    private func connect() {
        guard let device else {
            setError("Metal device is unavailable.")
            return
        }
        guard let selectedStreamID = selectedStreamID() else {
            setError("No stream selected.")
            return
        }

        do {
            let controlPlane = Syphon26ControlPlane(machServiceName: serviceField.stringValue)
            let client = try Syphon26Client(
                configuration: Syphon26ClientConfiguration(
                    device: device,
                    streamID: selectedStreamID,
                    preferredPixelFormats: selectedPreferredPixelFormats(),
                    controlPlane: controlPlane
                )
            )
            try client.start()
            self.controlPlane = controlPlane
            self.client = client
            observedFrames = 0
            repeatedReads = 0
            lastObservedFrames = 0
            lastMetricsTime = Date()
            lastSequence = 0
            connectButton.title = "Disconnect"
            statusLabel.stringValue = "Connected"
            statusLabel.textColor = .systemGreen
            setError("")
            updateControlAvailability()
            updateSelectedStreamLabels()
            startTimers()
            let connectedName = client.streamDescription?.name ?? selectedStreamDescription()?.name ?? selectedStreamID
            fputs(
                "Syphon26SimpleClientApp connected streamID=\(selectedStreamID) name=\"\(connectedName)\"\n",
                stderr
            )
        } catch {
            setError("Connect failed: \(error)")
            fputs("Syphon26SimpleClientApp connect failed: \(error)\n", stderr)
        }
    }

    private func disconnect() {
        pollTimer?.cancel()
        metricsTimer?.invalidate()
        pollTimer = nil
        metricsTimer = nil
        client?.stop()
        client = nil
        controlPlane = nil
        connectButton.title = "Connect"
        statusLabel.stringValue = "Disconnected"
        statusLabel.textColor = .labelColor
        streamIDLabel.stringValue = "-"
        meterView.value = 0
        fpsLabel.stringValue = "0 fps"
        previewRenderer?.clear(previewView, commandQueue: commandQueue)
        updateControlAvailability()
        fputs("Syphon26SimpleClientApp disconnected\n", stderr)
    }

    private func startTimers() {
        let interval = 1.0 / 120.0
        let pollTimer = DispatchSource.makeTimerSource(queue: .main)
        pollTimer.schedule(
            deadline: .now(),
            repeating: .nanoseconds(Int((interval * 1_000_000_000).rounded())),
            leeway: .nanoseconds(0)
        )
        pollTimer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.pollFrame()
            }
        }
        pollTimer.resume()
        self.pollTimer = pollTimer

        let metricsTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }
        RunLoop.main.add(metricsTimer, forMode: .common)
        self.metricsTimer = metricsTimer
    }

    private func startStreamRefreshTimer() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.client == nil else { return }
                self?.refreshStreams(selectName: self?.launchOptions.streamName)
                self?.maybeAutoConnect()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        streamRefreshTimer = timer
    }

    private func pollFrame() {
        guard let client else {
            return
        }
        do {
            guard let frame = try client.copyLatestFrame() else {
                repeatedReads += 1
                return
            }

            var shouldCloseWithCommandBuffer = false
            if frame.requiresGPUWait || previewRenderer != nil {
                guard let commandBuffer = commandQueue?.makeCommandBuffer() else {
                    throw Syphon26Error.commandBufferRequired
                }
                if frame.requiresGPUWait {
                    try frame.encodeWait(on: commandBuffer)
                    shouldCloseWithCommandBuffer = true
                }
                let previewEncoded = try previewRenderer?.renderTexture(
                    frame.texture,
                    to: previewView,
                    commandBuffer: commandBuffer
                ) ?? false
                shouldCloseWithCommandBuffer = shouldCloseWithCommandBuffer || previewEncoded
                if shouldCloseWithCommandBuffer {
                    commandBuffer.addCompletedHandler { _ in
                        frame.close()
                    }
                    commandBuffer.commit()
                } else {
                    frame.close()
                }
            } else {
                frame.close()
            }

            observedFrames += 1
            lastSequence = frame.sequence
            lastFrameWidth = frame.width
            lastFrameHeight = frame.height
            lastFrameFormat = pixelFormatLabel(frame.texture.pixelFormat)
            frameLabel.stringValue = "\(frame.width)x\(frame.height) \(lastFrameFormat)"
        } catch {
            setError("Receive failed: \(error)")
        }
    }

    private func updateMetrics() {
        guard let client else {
            return
        }
        let now = Date()
        let elapsed = max(now.timeIntervalSince(lastMetricsTime), 0.001)
        let frameDelta = observedFrames >= lastObservedFrames ? observedFrames - lastObservedFrames : 0
        let actualFPS = Double(frameDelta) / elapsed
        let target = expectedFPSForMeter()
        let ratio = actualFPS / max(target, 1)
        let diagnostics = client.diagnosticsSnapshot()

        lastObservedFrames = observedFrames
        lastMetricsTime = now

        meterView.value = min(ratio, 1)
        meterView.tintColor = ratio >= 0.95 ? .systemGreen : (ratio >= 0.75 ? .systemYellow : .systemRed)
        fpsLabel.stringValue = String(format: "%.1f fps", actualFPS)
        observedLabel.stringValue = "\(observedFrames)"
        repeatedLabel.stringValue = "\(repeatedReads) local, \(diagnostics.repeatedReads) diag"
        sequenceLabel.stringValue = "\(lastSequence)"
        syncLabel.stringValue = "\(diagnostics.syncMode) fallback=\(diagnostics.fallbackReason)"
        diagnosticsLabel.stringValue = "missed=\(diagnostics.missedFrames) gpuWait=\(diagnostics.gpuWaitNanoseconds / 1_000_000)ms sharedWaits=\(diagnostics.sharedEventWaits)"
        updateExpectedStatus(actualFPS: actualFPS)
        if launchOptions.autoConnect {
            fputs(
                "Syphon26SimpleClientApp metrics observed=\(observedFrames) repeated=\(repeatedReads) fps=\(String(format: "%.1f", actualFPS)) sequence=\(lastSequence) sync=\(diagnostics.syncMode) fallback=\(diagnostics.fallbackReason)\n",
                stderr
            )
        }
    }

    private func refreshStreams(selectName: String?) {
        do {
            let previousID = selectedStreamID()
            let controlPlane = Syphon26ControlPlane(machServiceName: serviceField.stringValue)
            let streams = try controlPlane.streams().sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            self.streams = streams

            streamPopup.removeAllItems()
            if streams.isEmpty {
                streamPopup.addItem(withTitle: "No Syphon26 streams")
                streamPopup.lastItem?.representedObject = nil
            } else {
                for stream in streams {
                    let appName = stream.appName ?? "Unknown App"
                    streamPopup.addItem(withTitle: "\(appName) / \(stream.name)  \(stream.width)x\(stream.height) \(pixelFormatLabel(stream.pixelFormat))")
                    streamPopup.lastItem?.representedObject = stream.streamID
                }
            }

            if let selectName,
               let index = streams.firstIndex(where: { $0.name == selectName }) {
                streamPopup.selectItem(at: index)
            } else if let previousID,
                      let index = streams.firstIndex(where: { $0.streamID == previousID }) {
                streamPopup.selectItem(at: index)
            } else if !streams.isEmpty {
                streamPopup.selectItem(at: 0)
            }
            updateSelectedStreamLabels()
            setError(streams.isEmpty ? "Waiting for Syphon26 streams." : "")
            if launchOptions.autoConnect {
                fputs("Syphon26SimpleClientApp streams=\(streams.count)\n", stderr)
            }
            maybeAutoConnect()
        } catch {
            setError("Stream refresh failed: \(error)")
            fputs("Syphon26SimpleClientApp stream refresh failed: \(error)\n", stderr)
        }
    }

    private func maybeAutoConnect() {
        guard launchOptions.autoConnect, client == nil, selectedStreamID() != nil else {
            return
        }
        connect()
    }

    private func selectedStreamID() -> Syphon26StreamID? {
        streamPopup.selectedItem?.representedObject as? Syphon26StreamID
    }

    private func selectedStreamDescription() -> Syphon26StreamDescription? {
        guard let id = selectedStreamID() else {
            return nil
        }
        return streams.first { $0.streamID == id }
    }

    private func updateSelectedStreamLabels() {
        guard let stream = selectedStreamDescription() ?? client?.streamDescription else {
            sourceLabel.stringValue = "-"
            expectedLabel.stringValue = "-"
            return
        }

        streamIDLabel.stringValue = stream.streamID
        sourceLabel.stringValue = "\(stream.name) \(stream.width)x\(stream.height) \(pixelFormatLabel(stream.pixelFormat))"

        if resolutionModePopup.titleOfSelectedItem == "Auto from stream" {
            widthField.stringValue = "\(stream.width)"
            heightField.stringValue = "\(stream.height)"
        }
        updateExpectedStatus(actualFPS: 0)
    }

    private func updateExpectedStatus(actualFPS: Double) {
        let expectedSize = expectedResolution()
        let sizeStatus: String
        if lastFrameWidth == 0 || lastFrameHeight == 0 {
            sizeStatus = "\(expectedSize.width)x\(expectedSize.height) waiting"
        } else if lastFrameWidth == expectedSize.width && lastFrameHeight == expectedSize.height {
            sizeStatus = "\(expectedSize.width)x\(expectedSize.height) ok"
        } else {
            sizeStatus = "\(expectedSize.width)x\(expectedSize.height) mismatch actual \(lastFrameWidth)x\(lastFrameHeight)"
        }

        let fpsText: String
        if fpsModePopup.titleOfSelectedItem == "Manual expected" {
            fpsText = String(format: "target %.0f fps, current %.1f fps", expectedFPSForMeter(), actualFPS)
        } else {
            fpsText = String(format: "observed %.1f fps", actualFPS)
        }
        expectedLabel.stringValue = "\(sizeStatus), \(fpsText)"
    }

    private func updateControlAvailability() {
        let connected = client != nil
        serviceField.isEnabled = !connected
        streamPopup.isEnabled = !connected
        refreshButton.isEnabled = !connected
        pixelFormatPopup.isEnabled = !connected

        let manualResolution = resolutionModePopup.titleOfSelectedItem == "Manual expected"
        widthField.isEnabled = manualResolution && !connected
        heightField.isEnabled = manualResolution && !connected

        let manualFPS = fpsModePopup.titleOfSelectedItem == "Manual expected"
        fpsField.isEnabled = manualFPS
    }

    private func selectedPreferredPixelFormats() -> [MTLPixelFormat] {
        switch pixelFormatPopup.titleOfSelectedItem {
        case "BGRA8":
            return [.bgra8Unorm]
        case "RGBA16F":
            return [.rgba16Float]
        default:
            return [.bgra8Unorm, .bgra8Unorm_srgb, .rgba16Float]
        }
    }

    private func expectedResolution() -> (width: Int, height: Int) {
        if resolutionModePopup.titleOfSelectedItem == "Auto from stream",
           let stream = selectedStreamDescription() ?? client?.streamDescription {
            return (stream.width, stream.height)
        }
        return (
            clamp(Int(widthField.stringValue) ?? 1920, min: 64, max: 8192),
            clamp(Int(heightField.stringValue) ?? 1080, min: 64, max: 8192)
        )
    }

    private func expectedFPSForMeter() -> Double {
        if fpsModePopup.titleOfSelectedItem == "Manual expected" {
            return min(max(Double(fpsField.stringValue) ?? 60, 1), 240)
        }
        return 60
    }

    private func pixelFormatLabel(_ pixelFormat: MTLPixelFormat) -> String {
        switch pixelFormat {
        case .rgba16Float:
            return "RGBA16F"
        case .bgra8Unorm_srgb:
            return "BGRA8_sRGB"
        default:
            return "BGRA8"
        }
    }

    private func clamp(_ value: Int, min minValue: Int, max maxValue: Int) -> Int {
        Swift.min(Swift.max(value, minValue), maxValue)
    }

    private func setError(_ message: String) {
        errorLabel.stringValue = message.isEmpty ? "OK" : message
        errorLabel.textColor = message.isEmpty ? .secondaryLabelColor : .systemRed
        if launchOptions.autoConnect, !message.isEmpty {
            fputs("Syphon26SimpleClientApp status: \(message)\n", stderr)
        }
    }
}

let app = NSApplication.shared
private let delegate = ClientAppDelegate(options: parseLaunchOptions())
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
