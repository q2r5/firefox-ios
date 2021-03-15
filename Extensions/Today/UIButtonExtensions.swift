// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit

extension UIButton {
    func setBackgroundColor(_ color: UIColor, forState state: UIControl.State) {
        let colorView = UIView(frame: CGRect(width: 1, height: 1))
        colorView.backgroundColor = color

        let colorImage = UIGraphicsImageRenderer(size: colorView.bounds.size).image { ctx in
            colorView.layer.render(in: ctx.cgContext)
        }

        self.setBackgroundImage(colorImage, for: state)
    }
}
