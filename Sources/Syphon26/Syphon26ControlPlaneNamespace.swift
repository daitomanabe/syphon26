import Darwin
import Foundation

struct Syphon26ControlPlaneNamespace: Equatable, Sendable {
    var name: String
    var userIdentifier: uid_t
    var runtimeDirectory: URL
    var validatesRuntimeDirectory: Bool

    static func current() -> Syphon26ControlPlaneNamespace {
        let uid = Darwin.getuid()
        return Syphon26ControlPlaneNamespace(
            name: "com.syphon26.control.\(uid)",
            userIdentifier: uid,
            runtimeDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("syphon26-\(uid)", isDirectory: true),
            validatesRuntimeDirectory: true
        )
    }

    static func testing(
        name: String = "com.syphon26.control.testing",
        userIdentifier: uid_t,
        runtimeDirectory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("syphon26-testing-\(UUID().uuidString)", isDirectory: true),
        validatesRuntimeDirectory: Bool = false
    ) -> Syphon26ControlPlaneNamespace {
        Syphon26ControlPlaneNamespace(
            name: name,
            userIdentifier: userIdentifier,
            runtimeDirectory: runtimeDirectory,
            validatesRuntimeDirectory: validatesRuntimeDirectory
        )
    }

    func prepareRuntimeDirectory(fileManager: FileManager = .default) throws {
        guard validatesRuntimeDirectory else {
            return
        }

        let path = runtimeDirectory.path
        if fileManager.fileExists(atPath: path) {
            guard (try? fileManager.destinationOfSymbolicLink(atPath: path)) == nil else {
                throw Syphon26Error.namespaceIsolationFailed
            }
        } else {
            try fileManager.createDirectory(
                at: runtimeDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: NSNumber(value: Int16(0o700))]
            )
        }

        var attributes = try fileManager.attributesOfItem(atPath: path)
        guard let owner = attributes[.ownerAccountID] as? NSNumber,
              owner.uint32Value == userIdentifier else {
            throw Syphon26Error.namespaceIsolationFailed
        }
        guard let permissions = attributes[.posixPermissions] as? NSNumber else {
            throw Syphon26Error.namespaceIsolationFailed
        }
        if permissions.uint16Value & 0o077 != 0 {
            try fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o700))],
                ofItemAtPath: path
            )
            attributes = try fileManager.attributesOfItem(atPath: path)
        }
        guard let finalPermissions = attributes[.posixPermissions] as? NSNumber,
              finalPermissions.uint16Value & 0o077 == 0 else {
            throw Syphon26Error.namespaceIsolationFailed
        }
    }

    func acceptsPeer(userIdentifier peerUserIdentifier: uid_t) -> Bool {
        peerUserIdentifier == userIdentifier
    }
}
