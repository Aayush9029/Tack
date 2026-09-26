import os

public enum Log {
    private static let subsystem = "ca.optimalapps.tack"

    public static let database = Logger(subsystem: subsystem, category: "database")
    public static let editor = Logger(subsystem: subsystem, category: "editor")
    public static let titles = Logger(subsystem: subsystem, category: "titles")

    public static let signposter = OSSignposter(subsystem: subsystem, category: .pointsOfInterest)
}
