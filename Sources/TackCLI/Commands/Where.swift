import ArgumentParser
import Dependencies
import Foundation
import TackKit

struct Where: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print where the notes are stored.")

    func run() throws {
        print(try DependencyValues.databaseURL().path(percentEncoded: false))
    }
}
