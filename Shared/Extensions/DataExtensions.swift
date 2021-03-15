// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Foundation
import CryptoKit

public extension Data {
    mutating func appendBytes(fromData data: Data) {
        var bytes = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &bytes, count: data.count)
        self.append(bytes, count: bytes.count)
    }

    func getBytes() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: self.count)
        self.copyBytes(to: &bytes, count: self.count)
        return bytes
    }

    func SHA1Hash() -> Data {
        let hash = Insecure.SHA1.hash(data: self)
        return Data(hash)
    }

    func SHA256Hash() -> Data {
        let hash = SHA256.hash(data: self)
        return Data(hash)
    }

    func HMACSHA256WithKey(_ key: Data) -> Data {
        if key.count == 0 {
            return Data()
        }

        let symmKey = SymmetricKey(data: key)
        let authCode  = HMAC<SHA256>.authenticationCode(for: self, using: symmKey)

        return Data(authCode)
    }
}
