// Copyright © 2021 Jack Maloney. All Rights Reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import VarInt

public enum MultiformatError: Error {
    case notImplemented
    case outOfAlphabetCharacter
    case invalidGroupSize
    case invalidNTet
    case invalidN
    case notCanonicalInput
    case noCorrespondingAlphabetCharacter
    case invalidFormat
    case multibaseDecodeError
    case unknownMulticodec
    case unknownMultihash
    case invalidDigestLength
    case invalidEncodingForCIDv0
}

/// A Type representing a CID (Content IDentifier) as defined in [multiformats/cid](https://github.com/multiformats/cid).
public struct CID: CustomStringConvertible, Equatable, Hashable, Codable {
    /// An enum representing the CID version.
    ///
    /// The rawValue Int is the appropriate multicodec value for the CID version.
    public enum Version: Int, Codable {
        /// CIDv0
        case v0 = 0
        /// CIDv1
        case v1 = 1
    }

    /// The version of this CID.
    ///
    /// CIDv0 can be converted to CIDv1 with the `CIDv1` function.
    public var version: Version
    /// The multicodec describing the format of the content identified by this CID.
    ///
    /// For CIDv0 this is alwaus `.dag_pb`
    public var codec: CodecPrefix
    /// The multihash containing the digest of the content identified by this CID.
    ///
    /// For CIDv0 this must be a `.sha2_256` Multihash.
    public var hash: Multihash

    /// Returns a textual representation of this CID.
    ///
    /// For CIDv0 this returns `Qm<hash as base58btc>`.
    /// For CIDv1 this returns the `<varint CID version><varint multicodec><multihash bytes>` encoded as a `.base32`
    /// multibase string (looks like "bafy...").
    public var description: String {
        do {
            switch self.version {
            case .v0:
                return try self.encoded(base: .base58btc)
            case .v1:
                return try self.encoded(base: .base32)
            }
        } catch {
            return "<\(error)>"
        }
    }

    /// Directly construct a CID with the specified properties.
    public init(version: Version, codec: CodecPrefix, hash: Multihash) {
        self.version = version
        self.codec = codec
        self.hash = hash
    }

    /// Parse a multibase encoded CID.
    public init(_ string: String) throws {
        var data: Data
        if string.count == 46, string.hasPrefix("Qm") {
            data = try Data(fromMultibaseEncodedString: String(string[string.startIndex...]), withEncoding: .base58btc)
        } else {
            data = try Data(fromMultibaseEncodedString: string)
        }
        try self.init(data)
    }

    /// Parse a CID directly from the data. This is data __after__ being multibase decoded. If you have a multibase string use the init(String) variant.
    public init(_ data: Data) throws {
        if data.count == 34, data.prefix(2) == Data([0x12, 0x20]) {
            // CIDv0
            self.version = .v0
            self.codec = .dag_pb
            self.hash = Multihash(code: .sha2_256, hash: data[data.startIndex.advanced(by: 2)...])
        } else {
            // CIDv1
            self.version = .v1

            // Decode CID version
            var buf = [UInt8](data)
            let (cidv, c1) = uVarInt(buf)
            guard cidv == self.version.rawValue else {
                throw MultiformatError.invalidFormat
            }
            buf = [UInt8](buf[c1...])

            let (codecid, c2) = uVarInt(buf)
            let codec = CodecPrefix(rawValue: codecid)
            guard codec != nil else {
                throw MultiformatError.unknownMulticodec
            }
            self.codec = codec!
            buf = [UInt8](buf[c2...])

            self.hash = try Multihash(Data(buf))
        }
    }

    /// Return a CIDv1 version of this CID. If it is already a CIDv1 this just returns `self`.
    public func CIDv1() -> CID {
        switch self.version {
        case .v0:
            var rv = self
            rv.version = .v1
            return rv
        case .v1:
            return self
        }
    }

    public var bytes: Data {
        switch self.version {
        case .v0:
            return self.hash.bytes
        case .v1:
            var data = Data()
            data.append(contentsOf: putUVarInt(UInt64(self.version.rawValue)))
            data.append(contentsOf: putUVarInt(self.codec.rawValue))
            data.append(self.hash.bytes)
            return data
        }
    }

    /// Encoded this CID to the specified multibase encoding.
    ///
    /// - Parameters:
    ///   - base: the `Multibase.Encoding` to encode the CID to
    public func encoded(base: Multibase.Encoding = .base58btc, multibasePrefix: Bool = true) throws -> String {
        guard self.version != .v0 || base == .base58btc else {
            throw MultiformatError.invalidEncodingForCIDv0
        }
        return try self.bytes.multibaseEncodedString(base, prefix: multibasePrefix && self.version != .v0)
    }

    public static func == (lhs: CID, rhs: CID) -> Bool {
        lhs.version == rhs.version && lhs.codec == rhs.codec && lhs.hash == rhs.hash
    }
}
