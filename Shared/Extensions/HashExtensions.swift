// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Foundation
import CryptoKit

extension Data {
    public var sha1: Data {
        return Data(Insecure.SHA1.hash(data: self))
    }

    public var sha256: Data {
        return Data(SHA256.hash(data: self))
    }
}

extension String {
    public var sha1: Data {
        let data = self.data(using: .utf8)!
        return data.sha1
    }

    public var sha256: Data {
        let data = self.data(using: .utf8)!
        return data.sha256
    }
}

extension Data {
    public func hmacSha256WithKey(_ key: Data) -> Data {
        let symKey = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: self, using: symKey)
        return Data(mac)
    }
}

extension String {
    public var utf8EncodedData: Data {
        return self.data(using: .utf8, allowLossyConversion: false)!
    }
}

extension Data {
    public var utf8EncodedString: String? {
        return String(data: self, encoding: .utf8)
    }
}

