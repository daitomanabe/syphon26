import Foundation
import Syphon26

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.first == "--xpc-mach-service" {
    let serviceName = arguments.dropFirst().first ?? Syphon26.defaultControlPlaneServiceName
    try Syphon26ProductionXPCService.run(serviceName: serviceName)
}

let serviceName = arguments.dropFirst().first ?? Syphon26.defaultControlPlaneServiceName

guard arguments.first == "--health-check" else {
    fputs("usage: Syphon26ControlPlaneService --health-check [service-name]\n       Syphon26ControlPlaneService --xpc-mach-service [service-name]\n", stderr)
    exit(64)
}

let reply = Syphon26XPCStartupReply(
    serviceName: serviceName,
    schemaVersion: Syphon26ControlPlaneWireProtocol.currentSchemaVersion,
    permissionToken: Syphon26ControlPlaneWireProtocol.localPermissionToken,
    bootIdentifier: Syphon26ControlPlaneWireProtocol.localBootIdentifier,
    processID: getpid()
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let data = try encoder.encode(reply)
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data("\n".utf8))
