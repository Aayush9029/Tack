import CryptoKit
import Foundation

/// A Raycast settings export (`.rayconfig`): "RAYCFG3", a little-endian header
/// length, a gzipped JSON header with the salt and IV, then the gzipped JSON
/// payload sealed with AES-256-GCM under an scrypt key from the export password.
public enum RaycastExport {
    public struct Note: Equatable, Sendable {
        public var title: String
        public var text: String
        public var createdAt: Date
        public var updatedAt: Date
    }

    public enum Failure: Error, Equatable, CustomStringConvertible {
        case notARaycastExport
        case unsupportedVersion(Int)
        case wrongPassword
        case noNotes

        public var description: String {
            switch self {
            case .notARaycastExport: "This is not a Raycast export."
            case let .unsupportedVersion(version): "Tack reads Raycast exports of version 3; this one is version \(version)."
            case .wrongPassword: "The password does not open this export."
            case .noNotes: "This export has no notes. Export again with Notes selected."
            }
        }
    }

    public static func notes(in data: Data, password: String) throws -> [Note] {
        let magic = Data("RAYCFG3\n".utf8)
        guard data.count > magic.count + 4, data.prefix(magic.count) == magic else { throw Failure.notARaycastExport }
        let lengthStart = data.startIndex + magic.count
        let length = data[lengthStart..<lengthStart + 4].enumerated().reduce(0) { $0 | Int($1.element) << (8 * $1.offset) }
        let headerStart = lengthStart + 4
        guard data.endIndex > headerStart + length + 16 else { throw Failure.notARaycastExport }
        let header = try JSONDecoder().decode(Header.self, from: Gzip.decompress(data[headerStart..<headerStart + length]))
        guard header.schemaVersion == 3 else { throw Failure.unsupportedVersion(header.schemaVersion) }
        guard let salt = Data(hex: header.encryption.salt), let iv = Data(hex: header.encryption.iv) else { throw Failure.notARaycastExport }

        let sealed = data[(headerStart + length)...]
        let key = Scrypt.derive(password: Data(password.utf8), salt: salt, n: 16384, r: 8, p: 1, length: 32)
        let payload: Data
        do {
            let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv), ciphertext: sealed.dropLast(16), tag: sealed.suffix(16))
            payload = try AES.GCM.open(box, using: SymmetricKey(data: key))
        } catch {
            throw Failure.wrongPassword
        }
        let export = try JSONDecoder.raycast.decode(Payload.self, from: Gzip.decompress(payload))
        guard let notes = export.notes?.notes, !notes.isEmpty else { throw Failure.noNotes }
        return notes.map { Note(title: $0.title, text: $0.text, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
    }

    private struct Header: Decodable {
        let schemaVersion: Int
        let encryption: Encryption
        struct Encryption: Decodable {
            let iv: String
            let salt: String
        }
    }

    private struct Payload: Decodable {
        let notes: Notes?
        struct Notes: Decodable {
            let notes: [RawNote]
        }
        struct RawNote: Decodable {
            let title: String
            let text: String
            let createdAt: Date
            let updatedAt: Date
        }
    }
}

private extension JSONDecoder {
    static var raycast: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: text) else {
                throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Not an ISO 8601 date: \(text)")
            }
            return date
        }
        return decoder
    }
}

private extension Data {
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}
