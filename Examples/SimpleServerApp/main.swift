import AppKit
import Foundation
import Syphon26SimpleUIShared

let options = Syphon26SampleArguments(arguments: Array(CommandLine.arguments.dropFirst()))

if options.smoke {
    print(try passivePreviewWindowSmokeJSON(title: "Syphon26 Simple Server"))
    exit(0)
}

let result = try Syphon26SampleRuntime.runServerSmoke(
    frames: options.frames,
    width: options.width,
    height: options.height
)
let app = NSApplication.shared
let delegate = Syphon26SampleAppDelegate(title: "Syphon26 Simple Server", result: result)
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
