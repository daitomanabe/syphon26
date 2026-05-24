import Foundation

public enum Syphon26Clock {
    public static func hostTime() -> Syphon26HostTime {
        mach_absolute_time()
    }

    public static func hostTimeNanoseconds() -> UInt64 {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return mach_absolute_time() * UInt64(info.numer) / UInt64(info.denom)
    }
}
