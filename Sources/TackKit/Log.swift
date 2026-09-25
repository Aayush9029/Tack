import os

/// One subsystem, a category per area. Signposts show up in Instruments' Points of
/// Interest and os_signpost lanes.
public enum Log {
    public static let subsystem = "ca.optimalapps.tack"

    public static let database = Logger(subsystem: subsystem, category: "database")
    public static let editor = Logger(subsystem: subsystem, category: "editor")
    public static let search = Logger(subsystem: subsystem, category: "search")
    public static let titles = Logger(subsystem: subsystem, category: "titles")
    public static let windows = Logger(subsystem: subsystem, category: "windows")

    public static let signposter = OSSignposter(subsystem: subsystem, category: .pointsOfInterest)
}
