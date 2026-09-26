extension String {
    var trimmingTrailingNewline: String {
        hasSuffix("\n") ? String(dropLast()) : self
    }
}
