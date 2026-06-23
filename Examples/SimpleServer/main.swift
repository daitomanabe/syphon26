import Foundation
import Syphon26SimpleUIShared

let options = Syphon26SampleArguments(arguments: Array(CommandLine.arguments.dropFirst()))
let result: Syphon26SampleRunResult
if let stateURL = options.stateURL {
    result = try Syphon26SampleRuntime.publishFileBackedServerState(
        stateURL: stateURL,
        frames: options.frames,
        width: options.width,
        height: options.height
    )
} else {
    result = try Syphon26SampleRuntime.runServerSmoke(
        frames: options.frames,
        width: options.width,
        height: options.height
    )
}

if options.json {
    print(try Syphon26SampleRuntime.encodeJSONLine(result))
} else {
    print("role=\(result.role) streamID=\(result.streamID) published=\(result.publishedFrames) scope=\(result.transportScope)")
}

if options.holdSeconds > 0 {
    Thread.sleep(forTimeInterval: options.holdSeconds)
}
