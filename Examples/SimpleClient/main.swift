import Foundation
import Syphon26SimpleUIShared

let options = Syphon26SampleArguments(arguments: Array(CommandLine.arguments.dropFirst()))
let result: Syphon26SampleRunResult
if let stateURL = options.stateURL {
    result = try Syphon26SampleRuntime.openFileBackedClientFrame(
        stateURL: stateURL,
        timeoutSeconds: options.timeoutSeconds
    )
} else {
    result = try Syphon26SampleRuntime.runClientPairSmoke(
        frames: options.frames,
        width: options.width,
        height: options.height
    )
}

if options.json {
    print(try Syphon26SampleRuntime.encodeJSONLine(result))
} else {
    print("role=\(result.role) streamID=\(result.streamID) received=\(result.receivedFrames) scope=\(result.transportScope)")
}
