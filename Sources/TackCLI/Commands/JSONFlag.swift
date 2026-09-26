import ArgumentParser

struct JSONFlag: ParsableArguments {
    @Flag(name: .long, help: "Print JSON.") var json = false
}
