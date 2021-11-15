// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit

extension UIWindow {
    static var keyWindow: UIWindow? {
        return UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first(where: { $0 is UIWindowScene })
            .flatMap({ $0 as? UIWindowScene })?.windows
            .first(where: \.isKeyWindow)
    }

    static var isLandscape: Bool {
        interfaceOrientation?
            .isLandscape ?? false
    }

    static var isPortrait: Bool {
        interfaceOrientation?
            .isPortrait ?? false
    }

    static var interfaceOrientation: UIInterfaceOrientation? {
        keyWindow?.windowScene?.interfaceOrientation
    }
}
