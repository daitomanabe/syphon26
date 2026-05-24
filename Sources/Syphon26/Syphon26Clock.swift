import Foundation

public enum Syphon26Clock {
    public static func hostTime() -> Syphon26HostTime {
        mach_absolute_time()
    }
}
