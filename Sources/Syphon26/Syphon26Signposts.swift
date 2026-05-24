import os

enum Syphon26Signposts {
    private static let log = OSLog(subsystem: "ws.daito.syphon26", category: "transport")

    static func acquire() {
        os_signpost(.event, log: log, name: "Acquire")
    }

    static func publish() {
        os_signpost(.event, log: log, name: "Publish")
    }

    static func consume() {
        os_signpost(.event, log: log, name: "Consume")
    }

    static func wait() {
        os_signpost(.event, log: log, name: "Wait")
    }

    static func retire() {
        os_signpost(.event, log: log, name: "Retire")
    }
}

