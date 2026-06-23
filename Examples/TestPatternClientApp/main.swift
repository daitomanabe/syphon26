import AppKit
import Foundation
import Syphon26TestPatternShared

let options = Syphon26TestPatternOptions(arguments: Array(CommandLine.arguments.dropFirst()))

if options.helpJSON {
    print(try encodeJSONLine(Syphon26TestPatternOptions.helpPayload(role: "client")))
    exit(0)
}

if options.smoke {
    let summary = try Syphon26TestPatternSmoke.runClient(options: options)
    print(try encodeJSONLine(summary))
    exit(0)
}

let app = NSApplication.shared
let delegate = Syphon26TestPatternClientDelegate(options: options)
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
