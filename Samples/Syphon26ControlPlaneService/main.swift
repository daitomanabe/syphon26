import Foundation
import Syphon26

do {
    var machServiceName = "com.syphon26.samples.control-plane"
    var arguments = Array(CommandLine.arguments.dropFirst())
    while !arguments.isEmpty {
        let key = arguments.removeFirst()
        guard !arguments.isEmpty else {
            throw Syphon26Error.invalidConfiguration
        }
        let value = arguments.removeFirst()
        switch key {
        case "--mach-service":
            machServiceName = value
        default:
            throw Syphon26Error.invalidConfiguration
        }
    }
    try Syphon26ControlPlaneServiceMain.run(machServiceName: machServiceName)
} catch {
    fputs("Syphon26ControlPlaneService failed: \(error)\n", stderr)
    exit(1)
}
