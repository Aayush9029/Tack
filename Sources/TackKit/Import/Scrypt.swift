import CommonCrypto
import Foundation

/// scrypt (RFC 7914), which Raycast derives its export key with. CryptoKit and
/// CommonCrypto have PBKDF2 but not scrypt.
enum Scrypt {
    static func derive(password: Data, salt: Data, n: Int, r: Int, p: Int, length: Int) -> Data {
        let blockSize = 128 * r
        var b = pbkdf2(password: password, salt: salt, length: p * blockSize)
        var words = [UInt32](repeating: 0, count: 32 * r)
        var v = [UInt32](repeating: 0, count: 32 * r * n)
        var scratch = [UInt32](repeating: 0, count: 32 * r)
        for chunk in 0..<p {
            b.withUnsafeBytes { raw in
                for index in words.indices {
                    words[index] = UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: chunk * blockSize + index * 4, as: UInt32.self))
                }
            }
            romix(&words, n: n, r: r, v: &v, scratch: &scratch)
            b.withUnsafeMutableBytes { raw in
                for index in words.indices {
                    raw.storeBytes(of: words[index].littleEndian, toByteOffset: chunk * blockSize + index * 4, as: UInt32.self)
                }
            }
        }
        return pbkdf2(password: password, salt: b, length: length)
    }

    private static func pbkdf2(password: Data, salt: Data, length: Int) -> Data {
        var output = Data(count: length)
        output.withUnsafeMutableBytes { out in
            password.withUnsafeBytes { pass in
                salt.withUnsafeBytes { salt in
                    _ = CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pass.baseAddress?.assumingMemoryBound(to: CChar.self), password.count,
                        salt.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 1,
                        out.baseAddress?.assumingMemoryBound(to: UInt8.self), length
                    )
                }
            }
        }
        return output
    }

    private static func romix(_ x: inout [UInt32], n: Int, r: Int, v: inout [UInt32], scratch: inout [UInt32]) {
        let words = 32 * r
        for index in 0..<n {
            v.replaceSubrange(index * words..<(index + 1) * words, with: x)
            blockMix(&x, r: r, scratch: &scratch)
        }
        for _ in 0..<n {
            let j = Int(x[(2 * r - 1) * 16]) & (n - 1)
            for k in 0..<words { x[k] ^= v[j * words + k] }
            blockMix(&x, r: r, scratch: &scratch)
        }
    }

    private static func blockMix(_ b: inout [UInt32], r: Int, scratch y: inout [UInt32]) {
        var x = Array(b[(2 * r - 1) * 16..<(2 * r) * 16])
        for i in 0..<(2 * r) {
            for k in 0..<16 { x[k] ^= b[i * 16 + k] }
            salsa20_8(&x)
            let destination = (i % 2 == 0 ? i / 2 : r + i / 2) * 16
            for k in 0..<16 { y[destination + k] = x[k] }
        }
        b = y
    }

    private static func salsa20_8(_ b: inout [UInt32]) {
        var x = b
        func rotate(_ a: UInt32, _ n: UInt32) -> UInt32 { (a << n) | (a >> (32 - n)) }
        for _ in 0..<4 {
            x[4] ^= rotate(x[0] &+ x[12], 7); x[8] ^= rotate(x[4] &+ x[0], 9)
            x[12] ^= rotate(x[8] &+ x[4], 13); x[0] ^= rotate(x[12] &+ x[8], 18)
            x[9] ^= rotate(x[5] &+ x[1], 7); x[13] ^= rotate(x[9] &+ x[5], 9)
            x[1] ^= rotate(x[13] &+ x[9], 13); x[5] ^= rotate(x[1] &+ x[13], 18)
            x[14] ^= rotate(x[10] &+ x[6], 7); x[2] ^= rotate(x[14] &+ x[10], 9)
            x[6] ^= rotate(x[2] &+ x[14], 13); x[10] ^= rotate(x[6] &+ x[2], 18)
            x[3] ^= rotate(x[15] &+ x[11], 7); x[7] ^= rotate(x[3] &+ x[15], 9)
            x[11] ^= rotate(x[7] &+ x[3], 13); x[15] ^= rotate(x[11] &+ x[7], 18)
            x[1] ^= rotate(x[0] &+ x[3], 7); x[2] ^= rotate(x[1] &+ x[0], 9)
            x[3] ^= rotate(x[2] &+ x[1], 13); x[0] ^= rotate(x[3] &+ x[2], 18)
            x[6] ^= rotate(x[5] &+ x[4], 7); x[7] ^= rotate(x[6] &+ x[5], 9)
            x[4] ^= rotate(x[7] &+ x[6], 13); x[5] ^= rotate(x[4] &+ x[7], 18)
            x[11] ^= rotate(x[10] &+ x[9], 7); x[8] ^= rotate(x[11] &+ x[10], 9)
            x[9] ^= rotate(x[8] &+ x[11], 13); x[10] ^= rotate(x[9] &+ x[8], 18)
            x[12] ^= rotate(x[15] &+ x[14], 7); x[13] ^= rotate(x[12] &+ x[15], 9)
            x[14] ^= rotate(x[13] &+ x[12], 13); x[15] ^= rotate(x[14] &+ x[13], 18)
        }
        for k in 0..<16 { b[k] = b[k] &+ x[k] }
    }
}
