// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Foundation
import UIKit

class TabMoreMenuHeader: UIView, NotificationThemeable {
    let imageView: UIImageView = .build { imgView in
        imgView.contentMode = .scaleAspectFill
        imgView.clipsToBounds = true
        imgView.layer.cornerRadius = ChronologicalTabsControllerUX.cornerRadius
        imgView.layer.borderWidth = 1
        imgView.layer.borderColor = UIColor.Photon.Grey30.cgColor
    }
    
    let titleLabel: UILabel = .build { title in
        title.numberOfLines = 2
        title.lineBreakMode = .byTruncatingTail
        title.font = UIFont.systemFont(ofSize: 17, weight: .regular)
    }
    
    let descriptionLabel: UILabel = .build { descriptionText in
        descriptionText.numberOfLines = 0
        descriptionText.lineBreakMode = .byWordWrapping
        descriptionText.font = UIFont.systemFont(ofSize: 14, weight: .regular)
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        setupView()
    }
    
    private func setupView() {
        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 100),
            imageView.widthAnchor.constraint(equalToConstant: 100),
            imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: ChronologicalTabsControllerUX.screenshotMarginLeftRight),
            imageView.topAnchor.constraint(equalTo: self.topAnchor, constant: ChronologicalTabsControllerUX.screenshotMarginTopBottom),
            imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -ChronologicalTabsControllerUX.screenshotMarginTopBottom),
            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: ChronologicalTabsControllerUX.screenshotMarginLeftRight),
            titleLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: ChronologicalTabsControllerUX.textMarginTopBottom),
            titleLabel.bottomAnchor.constraint(equalTo: descriptionLabel.topAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            descriptionLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: ChronologicalTabsControllerUX.screenshotMarginLeftRight),
            descriptionLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            descriptionLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -ChronologicalTabsControllerUX.textMarginTopBottom * CGFloat(titleLabel.numberOfLines))
        ])
        
        applyTheme()
    }
    
    func applyTheme() {
        backgroundColor = UIColor.secondarySystemGroupedBackground
        titleLabel.textColor = UIColor.label
        descriptionLabel.textColor = UIColor.secondaryLabel
    }
}
