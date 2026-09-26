import Compression
import Foundation

/// Gzip members as Raycast writes them: a header, raw DEFLATE, and a trailer.
enum Gzip {
    enum Failure: Error {
        case notGzip
        case corrupt
    }

    static func decompress(_ data: Data) throws -> Data {
        let bytes = [UInt8](data)
        guard bytes.count > 18, bytes[0] == 0x1F, bytes[1] == 0x8B, bytes[2] == 8 else { throw Failure.notGzip }
        let flags = bytes[3]
        var offset = 10
        if flags & 0x04 != 0, bytes.count > offset + 2 {
            offset += 2 + Int(bytes[offset]) + Int(bytes[offset + 1]) << 8
        }
        if flags & 0x08 != 0 { while offset < bytes.count, bytes[offset] != 0 { offset += 1 }; offset += 1 }
        if flags & 0x10 != 0 { while offset < bytes.count, bytes[offset] != 0 { offset += 1 }; offset += 1 }
        if flags & 0x02 != 0 { offset += 2 }
        guard offset < bytes.count - 8 else { throw Failure.corrupt }
        let size = Int(bytes[bytes.count - 4]) | Int(bytes[bytes.count - 3]) << 8 | Int(bytes[bytes.count - 2]) << 16 | Int(bytes[bytes.count - 1]) << 24
        let deflated = Data(bytes[offset..<(bytes.count - 8)])
        var output = Data(count: max(size, 1))
        let written = output.withUnsafeMutableBytes { out in
            deflated.withUnsafeBytes { input in
                compression_decode_buffer(
                    out.baseAddress!.assumingMemoryBound(to: UInt8.self), out.count,
                    input.baseAddress!.assumingMemoryBound(to: UInt8.self), input.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard written == size else { throw Failure.corrupt }
        return output
    }
}
