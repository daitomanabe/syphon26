import Foundation

public final class Syphon26Directory: @unchecked Sendable {
    public static let shared = Syphon26Directory()

    private init() {
    }

    public func start() throws {
    }

    public func stop() {
    }

    public func streams() -> [Syphon26StreamDescription] {
        Syphon26TransportRegistry.shared.descriptions()
    }

    public func stream(withID streamID: Syphon26StreamID) -> Syphon26StreamDescription? {
        Syphon26TransportRegistry.shared.stream(withID: streamID)?.description
    }

    public func streams(matching predicate: (Syphon26StreamDescription) -> Bool) -> [Syphon26StreamDescription] {
        streams().filter(predicate)
    }
}
