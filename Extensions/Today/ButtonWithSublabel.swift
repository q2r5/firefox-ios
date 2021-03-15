// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit
import SnapKit

class ButtonWithSublabel: UIButton {
    lazy var subLabel: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    lazy var label: UILabel = {
        let label = UILabel()
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        performLayout()
    }

    fileprivate func performLayout() {
        let buttonImage = self.imageView!
        self.titleLabel?.removeFromSuperview()
        addSubview(self.label)
        addSubview(self.subLabel)
        buttonImage.adjustsImageSizeForAccessibilityContentSizeCategory = true
        buttonImage.contentMode = .scaleAspectFit
        buttonImage.translatesAutoresizingMaskIntoConstraints = false
        
        buttonImage.snp.makeConstraints { make in
            make.left.centerY.equalTo(10)
            make.width.equalTo(self.label.snp.height)
        }
        self.label.snp.makeConstraints { make in
            make.left.equalTo(buttonImage.snp.right).offset(10)
            make.trailing.top.equalTo(self)
        }
        
        label.sizeToFit()
        
        self.subLabel.snp.makeConstraints { make in
            make.bottom.equalTo(self).inset(10)
            make.top.equalTo(self.label.snp.bottom)
            make.leading.trailing.equalTo(self.label)
        }
    }

    override func setTitle(_ text: String?, for state: UIControl.State) {
        self.label.text = text
        super.setTitle(text, for: state)
    }
}
