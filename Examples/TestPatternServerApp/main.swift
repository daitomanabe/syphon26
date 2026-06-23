import AppKit
import Foundation
import Syphon26TestPatternShared

let options = Syphon26TestPatternOptions(arguments: Array(CommandLine.arguments.dropFirst()))

if options.helpJSON {
    print(try encodeJSONLine(Syphon26TestPatternOptions.helpPayload(role: "server")))
    exit(0)
}

if options.smoke {
    let summary = try Syphon26TestPatternSmoke.runServer(options: options)
    print(try encodeJSONLine(summary))
    exit(0)
}

let app = NSApplication.shared
let delegate = Syphon26TestPatternServerDelegate(options: options)
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
