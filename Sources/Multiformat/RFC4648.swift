// Copyright © 2021 Jack Maloney. All Rights Reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

public extension Data {
    func asRFC4648Base64EncodedString(withPadding _: Bool = true) throws -> String {
        return ""
    }
}

public extension String {
    func decodeRFC4648Base64EncodedString() throws -> Data {
        return Data()
    }
}

extension Array where Element: FixedWidthInteger {
    var leadingZeroBitCount: Int {
        if self.count < 1 {
            return 0
        } else if self[0] != 0 {
            return self[0].leadingZeroBitCount
        } else {
            var bits = self.prefix(while: { b in b == 0 }).count * 8
            if let index = self.firstIndex(where: { b in b != 0 }) {
                bits += self[index].leadingZeroBitCount
            }
            return bits
        }
    }
}

enum RFC4648Error: Error {
    case outOfAlphabetCharacter
    case invalidGroupSize
    case invalidNTet
    case notCanonicalInput
    case noCorrespondingAlphabetCharacter
}

internal enum RFC4648 {
    enum Alphabet: String {
        case octal = "01234567"
        case base16 = "0123456789abcdef"
        case base16upper = "0123456789ABCDEF"
        case base32 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        case base32hex = "0123456789ABCDEFGHIJKLMNOPQRSTUV"
        case base64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        case base64url = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

        func asChars() -> [Character] {
            return self.rawValue.map { $0 }
        }
    }

    public static func encodeToBase64(_ data: Data, pad: Bool = true) throws -> String {
        let sextets = [UInt8](try [UInt8](data)
            .grouped(3)
            .map { try RFC4648.octetGroupToNTets($0, n: 6) }
            .joined())
        var rv = try encode(sextets, withAphabet: Alphabet.base64.asChars())
        if pad {
            rv = self.addPaddingCharacters(string: rv, forEncodingWithGroupSize: 4)
        }
        return String(rv)
    }

    internal static func addPaddingCharacters(string: [Character], paddingCharacter: Character = "=", forEncodingWithGroupSize groupSize: Int) -> [Character] {
        guard let group = string.grouped(groupSize).last else {
            return []
        }
        return string + Array(repeating: paddingCharacter, count: groupSize - group.count)
    }

    internal static func encode(_ data: [UInt8], withAphabet alphabet: [Character]) throws -> [Character] {
        return try data.map { byte in
            guard byte < alphabet.count else {
                throw RFC4648Error.noCorrespondingAlphabetCharacter
            }
            return alphabet[Int(byte)]
        }
    }

    public static func decodeBase64(_ string: String) throws -> [UInt8] {
        return [UInt8](try RFC4648
            .decodeAlphabet(string, alphabet: Alphabet.base64.asChars())
            .grouped(4)
            .map { try RFC4648.nTetGroupToOctets($0, n: 6) }
            .joined())
    }

    internal static func decodeAlphabet(_ string: String, alphabet: [Character], paddingCharacter: Character = "=", allowOutOfAlphabetCharacters: Bool = false) throws -> [UInt8] {
        if let i = string.firstIndex(of: paddingCharacter), string.suffix(from: i).contains(where: { $0 != paddingCharacter }) {
            throw RFC4648Error.notCanonicalInput
        }
        return try string
            .filter { $0 != paddingCharacter }
            .map { alphabet.firstIndex(of: $0) }
            .filter { i in
                guard i != nil else {
                    if !allowOutOfAlphabetCharacters {
                        throw RFC4648Error.outOfAlphabetCharacter
                    } else {
                        return false
                    }
                }
                return true
            }
            .map { UInt8($0!) }
    }

    /*
     *  Base 64:
     *
     *      +--first octet--+-second octet--+--third octet--+
     *      |7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|
     *      +-----------+---+-------+-------+---+-----------+
     *      |5 4 3 2 1 0|5 4 3 2 1 0|5 4 3 2 1 0|5 4 3 2 1 0|
     *      +--1.index--+--2.index--+--3.index--+--4.index--+
     *
     *  Base 32:
     *
     *      01234567 89012345 67890123 45678901 23456789
     *      +--------+--------+--------+--------+--------+
     *      |< 1 >< 2| >< 3 ><|.4 >< 5.|>< 6 ><.|7 >< 8 >|
     *      +--------+--------+--------+--------+--------+
     */

    internal static func octetGroupToNTets(_ input: [UInt8], n: Int = 5) throws -> [UInt8] {
        if input.isEmpty { return [] }
        let len = input.count
        let l = (lcm(8, n) / 8)
        guard input.count <= l else { throw RFC4648Error.invalidGroupSize }

        let input = input + Array(repeating: UInt8(0), count: l - input.count)
        let n = UInt8(n)
        var output = [UInt8]()
        var rhsOffset: UInt8 = n
        var i = 0
        var octet: UInt8 = input[i]
        var carry: UInt8 = 0

        while true {
            let (q, r) = octet.quotientAndRemainder(dividingBy: pow2(8 - rhsOffset))
            output.append(carry * pow2(rhsOffset) + q)
            rhsOffset = rhsOffset + n
            if rhsOffset < 8 {
                octet = r
                carry = 0
            } else {
                i += 1
                if i < input.count {
                    carry = r
                    octet = input[i]
                } else {
                    output.append(r)
                    break
                }
            }
            rhsOffset = rhsOffset % 8
        }

        let outSize = ceil(Double(8 * len) / Double(n))
        return [UInt8](output[0 ..< Int(outSize)])
    }

    internal static func nTetGroupToOctets(_ input: [UInt8], n: Int) throws -> [UInt8] {
        if input.isEmpty { return [] }
        let len = input.count
        let l = (lcm(8, n) / n)
        guard input.count <= l else { throw RFC4648Error.invalidGroupSize }

        let input = input + Array(repeating: UInt8(0), count: l - input.count)
        let n = UInt8(n)
        var j: Int = 0
        var output = [UInt8](repeating: 0, count: lcm(8, Int(n)) / 8)
        var rhsOffset: UInt8 = 0

        var q: UInt8 = 0, r: UInt8 = 0
        for i in input {
            if i >= pow2(n) {
                throw RFC4648Error.invalidNTet
            }
            // Handle carry
            output[j] += r * pow2(8 - rhsOffset)
            r = 0

            rhsOffset += n

            if rhsOffset < 8 {
                output[j] += i * pow2(8 - rhsOffset)
            } else {
                (q, r) = i.quotientAndRemainder(dividingBy: pow2(rhsOffset - 8))
                output[j] += q
                j += 1
            }

            rhsOffset = rhsOffset % 8
        }

        let outSize = Int(floor(Double(len * Int(n)) / Double(8)))

        guard r == 0, output[outSize...].allSatisfy({ $0 == 0 }) else {
            throw RFC4648Error.notCanonicalInput
        }

        return [UInt8](output[0 ..< outSize])
    }
}

@inlinable internal func pow2(_ x: UInt8) -> UInt8 {
    if x == 0 { return 1 }
    return 2 << (x - 1)
}

func gcd(_ a: Int, _ b: Int) -> Int {
    let r = a % b
    if r != 0 {
        return gcd(b, r)
    } else {
        return b
    }
}

func lcm(_ m: Int, _ n: Int) -> Int {
    return m * n / gcd(m, n)
}
